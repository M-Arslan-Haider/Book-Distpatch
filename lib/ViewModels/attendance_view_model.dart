//
//
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
// import 'dart:ui' as ui;
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:http/http.dart' as http;
//
// import '../Database/db_helper.dart';
// import '../Models/attendance_Model.dart';
// import '../Repositories/attendance_repository.dart';
// import 'location_view_model.dart';
//
// class AttendanceViewModel extends GetxController {
//   // ── Dependencies ──────────────────────────────────────────────────────────
//   final AttendanceRepository _repo       = AttendanceRepository();
//   final LocationViewModel    _locationVM = Get.put(LocationViewModel());
//
//   // ── Observables ───────────────────────────────────────────────────────────
//   var allAttendance = <AttendanceModel>[].obs;
//   var isClockedIn   = false.obs;
//   var elapsedTime   = '00:00:00'.obs;
//   var isLoading     = false.obs;
//
//   // ── Timer state ───────────────────────────────────────────────────────────
//   DateTime? _clockInTime;
//   Timer?    _timer;
//
//   // ── Serial counter state ──────────────────────────────────────────────────
//   int    _serialCounter = 1;
//   String _currentMonth  = DateFormat('MMM').format(DateTime.now());
//
//   // ── Full-res image cache (in memory only, not persisted to DB) ────────────
//   // Maps attendanceId → original bytes. Used so the API POST still sends
//   // the full-quality image even though DB stores a tiny compressed thumbnail.
//   final Map<String, Uint8List> _uploadBytesCache = {};
//
//   // ── SharedPreferences keys ────────────────────────────────────────────────
//   static const String _keyClockInTime   = 'clockInTime';
//   static const String _keyCurrentId     = 'currentAttendanceId';
//   static const String _keyAttendanceId  = 'attendanceId';
//   static const String _keyTotalTime     = 'totalTime';
//   static const String _keySecondsPassed = 'secondsPassed';
//   static const String _keyIsClockedIn   = 'isClockedIn';
//   static const String _keyLastDate      = 'last_attendance_date';
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // LIFECYCLE
//   // ─────────────────────────────────────────────────────────────────────────
//
//   @override
//   void onInit() {
//     super.onInit();
//     // ── Step 1: wipe oversized profile blobs that crash SQLite CursorWindow ──
//     // Must run BEFORE fetchAllAttendance / _restoreClockState so those queries
//     // don't hit the 2 MB row limit on existing records.
//     _repo.cleanupLargeProfiles().then((_) {
//       fetchAllAttendance();
//       _restoreClockState();
//     });
//     _initSerialCounter();
//   }
//
//   @override
//   void onClose() {
//     _stopTimer();
//     super.onClose();
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – SERIAL COUNTER
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> _checkAndResetSerialCounter() async {
//     final prefs = await SharedPreferences.getInstance();
//     final lastDateStr = prefs.getString(_keyLastDate);
//     final currentDate = DateFormat('dd-MMM-yyyy').format(DateTime.now());
//
//     if (lastDateStr != currentDate) {
//       // New day - reset counter
//       _serialCounter = 1;
//       await _saveSerialCounter();
//       await prefs.setString(_keyLastDate, currentDate);
//       debugPrint('📅 [VM] New day detected! Reset serial counter to 1');
//     } else {
//       // Same day - load existing counter
//       _serialCounter = prefs.getInt('attendanceSerialCounter') ?? 1;
//       debugPrint('📅 [VM] Same day, counter: $_serialCounter');
//     }
//   }
//
//   Future<void> _initSerialCounter() async {
//     final prefs = await SharedPreferences.getInstance();
//     final lastDateStr = prefs.getString(_keyLastDate);
//     final currentDate = DateFormat('dd-MMM-yyyy').format(DateTime.now());
//
//     if (lastDateStr != currentDate) {
//       _serialCounter = 1;
//       await _saveSerialCounter();
//       await prefs.setString(_keyLastDate, currentDate);
//       debugPrint('🔢 [VM] New day - serial counter reset to 1');
//     } else {
//       _serialCounter = prefs.getInt('attendanceSerialCounter') ?? 1;
//       debugPrint('🔢 [VM] Loaded serial counter: $_serialCounter');
//     }
//   }
//
//   Future<void> _saveSerialCounter() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setInt('attendanceSerialCounter', _serialCounter);
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – METHODS CALLED FROM timer_card.dart
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<bool> isLocationAvailable() async {
//     try {
//       return await Geolocator.isLocationServiceEnabled();
//     } catch (_) {
//       return true;
//     }
//   }
//
//   Future<void> updateCachedDistance(double distance) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setDouble('cachedDistance', distance);
//     debugPrint('📏 [VM] Cached distance updated: $distance km');
//   }
//
//   Future<void> syncUnposted() async => syncNow();
//
//   // ✅ FIX: photoBytes (Uint8List?) replaces photoPath (String)
//   // Bytes are read immediately at capture time in timer_card.dart — no file
//   // path is needed here, eliminating the race-condition that caused the
//   // profile image to disappear on some devices.
//   Future<void> saveFormAttendanceIn({
//     String empId    = '',
//     String empName  = '',
//     String job      = '',
//     String city     = '',
//     Uint8List? photoBytes,
//   }) async {
//     await clockIn(
//       empId      : empId,
//       empName    : empName,
//       job        : job,
//       city       : city,
//       photoBytes : photoBytes,
//     );
//   }
//
//   void stopElapsedTimer() {
//     _stopTimer();
//     elapsedTime.value = '00:00:00';
//     debugPrint('🛑 [VM] Elapsed timer stopped');
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – CLOCK-IN
//   // ─────────────────────────────────────────────────────────────────────────
//
//   // ✅ FIX: Accept Uint8List? photoBytes instead of String photoPath.
//   // This removes the need to read a file inside _handleBackgroundTasks, which
//   // was unreliable because the camera temp-file can vanish during the async
//   // GPS / permission checks that run before _handleBackgroundTasks is called.
//   Future<void> clockIn({
//     String     empId      = '',
//     String     empName    = '',
//     String     job        = '',
//     String     city       = '',
//     Uint8List? photoBytes,
//   }) async {
//     debugPrint('🎯 [VM] ===== CLOCK-IN STARTED =====');
//     debugPrint('📸 [VM] photoBytes received: ${photoBytes != null ? "${photoBytes.length} bytes" : "NULL ← photo will NOT be saved"}');
//
//     // Check for new day and reset counter if needed
//     await _checkAndResetSerialCounter();
//
//     // ✅ Fall back to SharedPreferences if caller left fields empty
//     if (empId.isEmpty || empName.isEmpty || job.isEmpty) {
//       final prefs = await SharedPreferences.getInstance();
//       if (empId.isEmpty)   empId   = _safeReadString(prefs, 'emp_id');
//       if (empName.isEmpty) empName = _safeReadStringFallback(prefs, ['emp_name', 'empName', 'employee_name', 'name', 'userName', 'user_name']);
//       if (job.isEmpty)     job     = _safeReadStringFallback(prefs, ['job', 'designation', 'role', 'emp_job', 'position', 'jobTitle']);
//       if (city.isEmpty)    city    = _safeReadStringFallback(prefs, ['city', 'emp_city', 'location']);
//       debugPrint('👤 [VM] Resolved from prefs — empId=$empId | empName=$empName | job=$job | city=$city');
//     }
//
//     // Guard: already clocked in
//     if (isClockedIn.value) {
//       Get.snackbar('Already Clocked In', 'You are already clocked in',
//           snackPosition: SnackPosition.TOP, backgroundColor: Colors.green);
//       return;
//     }
//
//     // Location service check
//     if (!await _isLocationServiceOn()) {
//       Get.snackbar('Location Required', 'Please turn on device location',
//           backgroundColor: Colors.red);
//       return;
//     }
//
//     // Generate attendance ID
//     String attendanceId = _buildAttendanceId(empId: empId);
//
//     if (await _idExistsInDb(attendanceId)) {
//       _serialCounter++;
//       await _saveSerialCounter();
//       attendanceId = _buildAttendanceId(empId: empId);
//       debugPrint('🔄 [VM] Duplicate found — regenerated: $attendanceId');
//     }
//
//     // Mark clocked-in immediately so UI responds fast
//     _clockInTime      = DateTime.now();
//     isClockedIn.value = true;
//     elapsedTime.value = '00:00:00';
//     _startTimer();
//
//     Get.snackbar('Clock-In Successful', 'You are now clocked in',
//         backgroundColor: Colors.green);
//     debugPrint('✅ [VM] Clock-in set. ID: $attendanceId');
//
//     // Background: persist & sync
//     await _handleBackgroundTasks(
//       attendanceId : attendanceId,
//       empId        : empId,
//       empName      : empName,
//       job          : job,
//       city         : city,
//       photoBytes   : photoBytes,
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – ATD ID BUILDER
//   // ─────────────────────────────────────────────────────────────────────────
//
//   String _buildAttendanceId({required String empId}) {
//     final now = DateTime.now();
//     final day = DateFormat('dd').format(now);
//     final month = DateFormat('MMM').format(now);
//     final serial = _serialCounter.toString().padLeft(3, '0');
//     final empPart = empId.padLeft(2, '0');
//
//     // Get company code from DBHelper
//     final String companyCode = DBHelper.getCompanyCode() ?? '';
//
//     // Build ID with company code prefix
//     String id;
//     if (companyCode.isNotEmpty) {
//       id = '$companyCode-ATD-EMP-$empPart-$day-$month-$serial';
//     } else {
//       id = 'ATD-EMP-$empPart-$day-$month-$serial';
//     }
//
//     debugPrint('🆔 Generated ID: $id (counter: $_serialCounter, company: $companyCode)');
//     return id;
//   }
//
//   Future<bool> _idExistsInDb(String id) async {
//     try {
//       // Use idExists() which queries only by primary key — avoids reading the
//       // oversized profile column that crashes SQLite CursorWindow.
//       return await _repo.idExists(id);
//     } catch (e) {
//       debugPrint('❌ [VM] _idExistsInDb error: $e');
//       return false; // safe default: allow the insert to proceed
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – FETCH / ADD / DELETE
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> fetchAllAttendance() async {
//     try {
//       final records = await _repo.getAll();
//       allAttendance.value = records;
//     } catch (e) {
//       // Old rows may have oversized profile blobs that crash SQLite CursorWindow.
//       // Swallow the error — UI stays stale but clock-in/out still works.
//       debugPrint('⚠️ [VM] fetchAllAttendance failed (large rows in DB): $e');
//     }
//   }
//
//   Future<void> addAttendance(AttendanceModel model) async {
//     await _repo.add(model);
//     // Do NOT let a fetchAllAttendance crash abort the insert.
//     // The insert above already succeeded — just refresh best-effort.
//     try {
//       await fetchAllAttendance();
//     } catch (e) {
//       debugPrint('⚠️ [VM] addAttendance – fetchAll failed (ignored): $e');
//     }
//   }
//
//   Future<void> deleteAttendance(String id) async {
//     await _repo.delete(id);
//     try {
//       await fetchAllAttendance();
//     } catch (e) {
//       debugPrint('⚠️ [VM] deleteAttendance – fetchAll failed (ignored): $e');
//     }
//   }
//
//   // ✅ FIX 2: syncNow() now passes _uploadBytesCache so manual re-syncs
//   // also send the full-res profile photo. Previously called syncUnposted()
//   // (no bytes), which meant retried syncs uploaded no photo at all.
//   Future<void> syncNow() async {
//     final status = await _internetStatus();
//     if (status != 'none') {
//       debugPrint('🌐 [VM] Manual sync triggered');
//       await _repo.syncUnpostedWithBytes(_uploadBytesCache);
//       // Clear cache only AFTER a successful sync attempt
//       _uploadBytesCache.clear();
//       try {
//         await fetchAllAttendance();
//       } catch (e) {
//         debugPrint('⚠️ [VM] syncNow – fetchAll failed (ignored): $e');
//       }
//     } else {
//       debugPrint('🌐 [VM] No internet – sync skipped');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – CLOCK-IN STATE HELPERS
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<String?> getCurrentAttendanceId() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString(_keyCurrentId)
//         ?? prefs.getString(_keyAttendanceId)
//         ?? prefs.getString('clockInAttendanceId');
//   }
//
//   Future<void> clearClockInState() async {
//     _stopTimer();
//     isClockedIn.value = false;
//     _clockInTime      = null;
//     elapsedTime.value = '00:00:00';
//
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_keyClockInTime);
//     await prefs.remove(_keyTotalTime);
//     await prefs.setInt(_keySecondsPassed, 0);
//     await prefs.setBool(_keyIsClockedIn, false);
//
//     final currentId = prefs.getString(_keyCurrentId);
//     if (currentId != null) {
//       await prefs.setString('usedAttendanceId', currentId);
//       await prefs.remove(_keyCurrentId);
//     }
//
//     debugPrint('🔄 [VM] Clock-in state cleared');
//   }
//
//   Future<Map<String, dynamic>> getAttendanceStatus() async {
//     final prefs        = await SharedPreferences.getInstance();
//     final currentId    = prefs.getString(_keyCurrentId);
//     final clockInTime  = prefs.getString(_keyClockInTime);
//     final isClockedInS = prefs.getBool(_keyIsClockedIn) ?? false;
//
//     bool idInDb = false;
//     int totalRecords = 0;
//     try {
//       final allRecords = await _repo.getAll();
//       totalRecords = allRecords.length;
//       idInDb = currentId != null &&
//           allRecords.any((r) => r.attendance_in_id == currentId);
//     } catch (_) {
//       // large rows — best effort
//     }
//
//     return {
//       'currentId'   : currentId,
//       'clockInTime' : clockInTime,
//       'isClockedIn' : isClockedInS,
//       'totalRecords': totalRecords,
//       'idExistsInDB': idInDb,
//     };
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – DUPLICATE CLEANUP
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<bool> checkForDuplicate(String attendanceId) async {
//     try {
//       final records = await _repo.getAll();
//       return records.any((r) => r.attendance_in_id == attendanceId);
//     } catch (e) {
//       debugPrint('❌ [VM] checkForDuplicate error: $e');
//       return false;
//     }
//   }
//
//   Future<void> cleanDuplicateRecords() async {
//     try {
//       final allRecords = await _repo.getAll();
//       final seen       = <String>{};
//       final toDelete   = <String>[];
//
//       for (final r in allRecords) {
//         final id = r.attendance_in_id?.toString() ?? '';
//         if (id.isEmpty) continue;
//         if (seen.contains(id)) {
//           toDelete.add(id);
//         } else {
//           seen.add(id);
//         }
//       }
//
//       for (final id in toDelete) {
//         await _repo.delete(id);
//         debugPrint('🗑️ [VM] Removed duplicate: $id');
//       }
//
//       if (toDelete.isNotEmpty) {
//         debugPrint('✅ [VM] Cleaned ${toDelete.length} duplicates');
//         await fetchAllAttendance();
//       } else {
//         debugPrint('✅ [VM] No duplicates found');
//       }
//     } catch (e) {
//       debugPrint('❌ [VM] cleanDuplicateRecords error: $e');
//     }
//   }
//
//   Future<void> forceCleanup() async {
//     debugPrint('🧹 [VM] Force cleanup started...');
//     await cleanDuplicateRecords();
//
//     final prefs        = await SharedPreferences.getInstance();
//     final isClockedInS = prefs.getBool(_keyIsClockedIn) ?? false;
//     final clockInTime  = prefs.getString(_keyClockInTime);
//
//     if (isClockedInS && clockInTime == null) {
//       debugPrint('⚠️ [VM] Inconsistent state – resetting');
//       await prefs.setBool(_keyIsClockedIn, false);
//     }
//
//     final allRecords = await _repo.getAll();
//     final currentId  = prefs.getString(_keyCurrentId);
//     if (currentId != null &&
//         !allRecords.any((r) => r.attendance_in_id == currentId)) {
//       debugPrint('⚠️ [VM] Orphaned currentId removed: $currentId');
//       await prefs.remove(_keyCurrentId);
//     }
//
//     debugPrint('✅ [VM] Force cleanup done');
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – BACKGROUND TASKS AFTER CLOCK-IN
//   // ─────────────────────────────────────────────────────────────────────────
//
//   // ✅ FIX: photoBytes (Uint8List?) replaces photoPath (String).
//   //
//   // OLD (broken) approach:
//   //   • timer_card captured the photo → got XFile.path (String)
//   //   • Passed the path to this method
//   //   • This method LATER tried to open the file — by which time the OS had
//   //     sometimes already cleared the camera temp-file, so photoFile.exists()
//   //     returned false → profile was silently dropped.
//   //
//   // NEW (fixed) approach:
//   //   • timer_card reads the bytes IMMEDIATELY after capture (before any async
//   //     gaps) and passes the raw Uint8List here.
//   //   • No file I/O needed here — bytes are always present.
//   Future<void> _handleBackgroundTasks({
//     required String     attendanceId,
//     required String     empId,
//     required String     empName,
//     required String     job,
//     required String     city,
//     Uint8List?          photoBytes,
//   }) async {
//     debugPrint('🛰 [VM] Background tasks started...');
//     debugPrint('📸 [VM] photoBytes in background tasks: ${photoBytes != null ? "${photoBytes.length} bytes" : "NULL"}');
//
//     try {
//       final prefs = await SharedPreferences.getInstance();
//
//       // A. Persist clock-in state
//       await prefs.setString(_keyClockInTime, _clockInTime!.toIso8601String());
//       await prefs.setString(_keyCurrentId, attendanceId);
//       await prefs.setString(_keyAttendanceId, attendanceId);
//       await prefs.setString('clockInAttendanceId', attendanceId);
//       await prefs.setBool(_keyIsClockedIn, true);
//       await prefs.setInt(_keySecondsPassed, 0);
//       await prefs.remove(_keyTotalTime);
//
//       // B. Get GPS
//       final gps = await _getValidGPS();
//       final lat = gps['lat']!;
//       final lng = gps['lng']!;
//
//       // Use the selected location's address (set when user picks a geofence
//       // location) if it exists; fall back to GPS reverse-geocoded address.
//       // For non-geofenced users neither will be set, so we reverse-geocode
//       // the live GPS coordinates via the free Nominatim API.
//       final String selectedLocAddress =
//           prefs.getString('selected_location_address') ?? '';
//       // location_name is the human-readable name the geofenced employee
//       // chose from LocationSelectionScreen. Empty for non-geofenced users.
//       final String selectedLocationName =
//           prefs.getString('selected_location_name') ?? '';
//       String address = selectedLocAddress.isNotEmpty
//           ? selectedLocAddress
//           : _locationVM.shopAddress.value;
//
//       if (address.isEmpty) {
//         debugPrint('📍 [VM] No pre-set address — reverse-geocoding $lat,$lng for non-geofenced user');
//         address = await _reverseGeocode(lat, lng);
//       }
//       debugPrint('📍 [VM] GPS: lat=$lat, lng=$lng | address source: '
//           '${selectedLocAddress.isNotEmpty ? "selected_location" : address.isNotEmpty ? "reverse_geocode" : "none"} → "$address"');
//       debugPrint('📍 [VM] location_name: ${selectedLocationName.isNotEmpty ? "\"$selectedLocationName\"" : "(empty — non-geofenced user)"}');
//
//       // C. Capture exact clock-in datetime
//       final DateTime clockInNow = _clockInTime ?? DateTime.now();
//
//       // D. Compress to tiny thumbnail for SQLite (avoids CursorWindow 2MB crash).
//       //    Full-res bytes are cached in memory for the API POST.
//       String? profileBase64;
//       if (photoBytes != null && photoBytes.isNotEmpty) {
//         try {
//           final Uint8List? compressed = await _compressForStorage(photoBytes);
//           final Uint8List storageBytes = compressed ?? photoBytes;
//           profileBase64 = base64Encode(storageBytes);
//           // Cache full-res for the API upload (not stored in DB)
//           _uploadBytesCache[attendanceId] = photoBytes;
//           debugPrint(
//             '📸 [VM] ✅ Profile compressed — '
//                 'original: ${photoBytes.length} B → '
//                 'storage: ${storageBytes.length} B → '
//                 'base64: ${profileBase64.length} chars',
//           );
//         } catch (e) {
//           debugPrint('❌ [VM] base64Encode FAILED: $e — profile will be NULL for this record');
//           profileBase64 = null;
//         }
//       } else {
//         debugPrint('⚠️ [VM] photoBytes is ${photoBytes == null ? "null" : "empty"} — profile NOT saved. '
//             'Check that timer_card.dart read the photo bytes before any await calls.');
//       }
//
//       // ✅ FIX 1: Read company_code and include it in the model.
//       // Previously company_code was never set here, so the server always
//       // received an empty string and could not route / store the record.
//       final String companyCode = DBHelper.getCompanyCode() ?? '';
//       debugPrint('🏢 [VM] company_code for this clock-in: "$companyCode"');
//
//       // E. Save to local DB
//       final model = AttendanceModel(
//         attendance_in_id  : attendanceId,
//         emp_id            : empId,
//         emp_name          : empName,
//         job               : job,
//         lat_in            : lat.toString(),
//         lng_in            : lng.toString(),
//         city              : city,
//         address           : address,
//         location_name     : selectedLocationName, // geofenced users only; empty for non-geofenced
//         attendance_in_date: clockInNow,
//         attendance_in_time: clockInNow,
//         profile           : profileBase64,   // base64 String or null
//         company_code      : companyCode,
//         posted            : 0,
//       );
//       await addAttendance(model);
//       debugPrint(
//         '✅ [VM] Saved to local DB: $attendanceId | empId=$empId | empName=$empName '
//             '| job=$job | company=$companyCode '
//             '| time=${DateFormat("hh:mm:ss a").format(clockInNow)} '
//             '| profile=${profileBase64 != null ? "✅ ${profileBase64.length} chars" : "❌ null"}',
//       );
//
//       // F. Increment serial for next clock-in
//       _serialCounter++;
//       await _saveSerialCounter();
//       debugPrint('🔢 [VM] Serial counter after increment: $_serialCounter');
//
//       // G. Try server sync — pass full-res bytes cache so API gets original photo
//       final status = await _internetStatus()
//           .timeout(const Duration(seconds: 3), onTimeout: () => 'none');
//
//       if (status != 'none') {
//         debugPrint('🌐 [VM] Syncing to server...');
//         await _repo.syncUnpostedWithBytes(_uploadBytesCache);
//         // ✅ FIX 3: Do NOT remove the cache entry here prematurely.
//         // If this sync failed for this record, syncNow() (manual retry) needs
//         // the bytes to send the photo. The cache is cleared in syncNow() after
//         // a successful sync, or stays in memory until next app session.
//         try { await fetchAllAttendance(); } catch (_) {}
//         debugPrint('✅ [VM] Server sync complete');
//       } else {
//         debugPrint('🌐 [VM] No internet – will sync later');
//       }
//     } catch (e) {
//       debugPrint('⚠️ [VM] Background tasks error: $e');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – GPS HELPERS
//   // ─────────────────────────────────────────────────────────────────────────
//
//   // Reverse-geocodes a lat/lng to a human-readable address using the free
//   // OpenStreetMap Nominatim API. Called only for non-geofenced users whose
//   // address would otherwise be empty. Returns '' on any failure so the rest
//   // of the clock-in flow is never interrupted.
//   Future<String> _reverseGeocode(double lat, double lng) async {
//     if (lat == 0.0 && lng == 0.0) return '';
//     try {
//       final uri = Uri.parse(
//         'https://nominatim.openstreetmap.org/reverse'
//             '?format=jsonv2&lat=$lat&lon=$lng',
//       );
//       final response = await http.get(uri, headers: {
//         'Accept': 'application/json',
//         // Nominatim requires a meaningful User-Agent
//         'User-Agent': 'GPSWorkforceMonitor/1.0',
//       }).timeout(const Duration(seconds: 10));
//
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//         final String display = data['display_name']?.toString() ?? '';
//         debugPrint('🗺️ [VM] Reverse geocode → "$display"');
//         return display;
//       }
//       debugPrint('⚠️ [VM] Reverse geocode HTTP ${response.statusCode}');
//     } catch (e) {
//       debugPrint('⚠️ [VM] Reverse geocode failed: $e');
//     }
//     return '';
//   }
//
//   Future<bool> _isLocationServiceOn() async {
//     try {
//       return await Geolocator.isLocationServiceEnabled();
//     } catch (_) {
//       return true;
//     }
//   }
//
//   Future<Map<String, double>> _getValidGPS() async {
//     try {
//       final pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//         timeLimit: const Duration(seconds: 10),
//       );
//       if (pos.latitude != 0.0 || pos.longitude != 0.0) {
//         debugPrint('✅ [GPS] Fresh: ${pos.latitude}, ${pos.longitude}');
//         return {'lat': pos.latitude, 'lng': pos.longitude};
//       }
//     } catch (e) {
//       debugPrint('⚠️ [GPS] getCurrentPosition failed: $e');
//     }
//
//     for (int i = 0; i < 10; i++) {
//       await Future.delayed(const Duration(milliseconds: 500));
//       final lat = _locationVM.globalLatitude1.value;
//       final lng = _locationVM.globalLongitude1.value;
//       if (lat != 0.0 || lng != 0.0) {
//         debugPrint('✅ [GPS] From LocationViewModel: $lat, $lng');
//         return {'lat': lat, 'lng': lng};
//       }
//     }
//
//     try {
//       final last = await Geolocator.getLastKnownPosition();
//       if (last != null && (last.latitude != 0.0 || last.longitude != 0.0)) {
//         debugPrint('✅ [GPS] Last known: ${last.latitude}, ${last.longitude}');
//         return {'lat': last.latitude, 'lng': last.longitude};
//       }
//     } catch (e) {
//       debugPrint('⚠️ [GPS] getLastKnownPosition failed: $e');
//     }
//
//     debugPrint('⚠️ [GPS] All attempts failed – returning 0,0');
//     return {
//       'lat': _locationVM.globalLatitude1.value,
//       'lng': _locationVM.globalLongitude1.value,
//     };
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – INTERNET CHECK
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<String> _internetStatus() async {
//     try {
//       final res = await http
//           .head(Uri.parse('https://www.google.com'))
//           .timeout(const Duration(seconds: 3));
//       return res.statusCode == 200 ? 'fast' : 'slow';
//     } on TimeoutException {
//       return 'slow';
//     } on SocketException {
//       return 'none';
//     } catch (_) {
//       return 'none';
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – TIMER
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> _restoreClockState() async {
//     final prefs         = await SharedPreferences.getInstance();
//     final clockInString = prefs.getString(_keyClockInTime);
//
//     if (clockInString != null) {
//       _clockInTime      = DateTime.parse(clockInString);
//       isClockedIn.value = true;
//       _startTimer();
//       debugPrint('🔄 [VM] Restored clock-in state from: $_clockInTime');
//     }
//   }
//
//   void _startTimer() {
//     if (_clockInTime == null) return;
//     _timer?.cancel();
//
//     _timer = Timer.periodic(const Duration(seconds: 1), (t) {
//       final duration = DateTime.now().difference(_clockInTime!);
//       String two(int n) => n.toString().padLeft(2, '0');
//       elapsedTime.value =
//       '${two(duration.inHours)}:${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))}';
//
//       if (duration.inSeconds % 60 == 0) {
//         _saveTotalTime(elapsedTime.value);
//       }
//     });
//
//     debugPrint('✅ [VM] Timer started');
//   }
//
//   void _stopTimer() {
//     _timer?.cancel();
//     _timer = null;
//     debugPrint('🛑 [VM] Timer stopped');
//   }
//
//   // ── Safe Prefs Readers ────────────────────────────────────────────────────
//
//   String _safeReadString(SharedPreferences prefs, String key) {
//     try {
//       final dynamic raw = prefs.get(key);
//       if (raw == null) return '';
//       return raw.toString();
//     } catch (_) {
//       return '';
//     }
//   }
//
//   String _safeReadStringFallback(SharedPreferences prefs, List<String> keys) {
//     for (final key in keys) {
//       try {
//         final dynamic raw = prefs.get(key);
//         if (raw != null) {
//           final String val = raw.toString().trim();
//           if (val.isNotEmpty) {
//             debugPrint('   ✅ [VM PREFS] "$key" = "$val"');
//             return val;
//           }
//         }
//       } catch (_) {}
//     }
//     debugPrint('   ⚠️ [VM PREFS] None found in: $keys');
//     return '';
//   }
//
//   Future<void> _saveTotalTime(String time) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_keyTotalTime, time);
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – COMPRESS IMAGE FOR SQLITE STORAGE (no external package)
//   //
//   // Shrinks the photo to a 60×60 PNG thumbnail using Flutter's built-in
//   // dart:ui codec. Output is ~3–8 KB (from ~1 MB), safely under the SQLite
//   // CursorWindow 2 MB row limit. Full-res bytes are kept in _uploadBytesCache
//   // so the API POST still sends the original quality image.
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<Uint8List?> _compressForStorage(Uint8List original) async {
//     try {
//       final ui.Codec codec = await ui.instantiateImageCodec(
//         original,
//         targetWidth: 60,
//         targetHeight: 60,
//       );
//       final ui.FrameInfo frame = await codec.getNextFrame();
//       final ByteData? byteData =
//       await frame.image.toByteData(format: ui.ImageByteFormat.png);
//       frame.image.dispose();
//       codec.dispose();
//       if (byteData == null) return null;
//       final result = byteData.buffer.asUint8List();
//       debugPrint('🗜️ [VM] Compressed thumbnail: ${original.length} B → ${result.length} B');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [VM] _compressForStorage error: $e');
//       return null;
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – GENERATE ATTENDANCE ID (used externally if needed)
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<String> generateAttendanceId(String empId) async {
//     await _checkAndResetSerialCounter();
//     String attendanceId = _buildAttendanceId(empId: empId);
//
//     // Check for duplicates and regenerate if needed
//     while (await _idExistsInDb(attendanceId)) {
//       _serialCounter++;
//       await _saveSerialCounter();
//       attendanceId = _buildAttendanceId(empId: empId);
//     }
//
//     debugPrint('🆔 [VM] Generated attendance ID: $attendanceId');
//     return attendanceId;
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../Database/db_helper.dart';
import '../Models/attendance_Model.dart';
import '../Repositories/attendance_repository.dart';
import '../constants.dart';
import 'location_view_model.dart';

class AttendanceViewModel extends GetxController {
  final AttendanceRepository _repo = AttendanceRepository();
  final LocationViewModel _locationVM = Get.put(LocationViewModel());

  var allAttendance = <AttendanceModel>[].obs;
  var isClockedIn = false.obs;
  var elapsedTime = '00:00:00'.obs;
  var isLoading = false.obs;

  DateTime? _clockInTime;
  Timer? _timer;

  int _serialCounter = 1;
  String _currentMonth = DateFormat('MMM').format(DateTime.now());

  final Map<String, Uint8List> _uploadBytesCache = {};

  static const String _keyClockInTime = 'clockInTime';
  static const String _keyCurrentId = 'currentAttendanceId';
  static const String _keyAttendanceId = 'attendanceId';
  static const String _keyTotalTime = 'totalTime';
  static const String _keySecondsPassed = 'secondsPassed';
  static const String _keyIsClockedIn = 'isClockedIn';
  static const String _keyLastDate = 'last_attendance_date';

  @override
  void onInit() {
    super.onInit();
    _repo.cleanupLargeProfiles().then((_) {
      fetchAllAttendance();
      _restoreClockState();
    });
  }

  @override
  void onClose() {
    _stopTimer();
    super.onClose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – Initialize serial counter (called after login)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> initSerialCounter() async {
    await _initSerialCounter();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – CHECK AND RESTORE ATTENDANCE STATE AFTER LOGIN
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> checkAndRestoreAttendanceState({
    required String empId,
    required String companyCode,
  }) async {
    debugPrint('🔄 [VM] Checking existing attendance for emp_id=$empId, company=$companyCode');

    try {
      final hasRecords = await _repo.employeeHasAttendance(
        empId: empId,
        companyCode: companyCode,
      );

      if (!hasRecords) {
        debugPrint('📝 [VM] No existing records - this is a NEW employee');
        await _initSerialCounter();
        return false;
      }

      debugPrint('✅ [VM] Employee has existing records - checking state');

      // Try to restore serial counter
      await _restoreSerialCounterFromServer(empId, companyCode);

      // Note: Full state restoration (clocked-in status) would require
      // an additional API endpoint to check if employee is currently clocked in
      // For now, we assume they are clocked out and just restore the counter

      return false;
    } catch (e) {
      debugPrint('❌ [VM] checkAndRestoreAttendanceState error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – SERIAL COUNTER
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _initSerialCounter() async {
    final prefs = await SharedPreferences.getInstance();
    final String? empId = prefs.getString(prefUserId);
    final String? companyCode = DBHelper.getCompanyCode();

    if (empId == null || empId.isEmpty || companyCode == null || companyCode.isEmpty) {
      debugPrint('⚠️ [VM] Cannot init serial counter: missing emp_id or company_code');
      _serialCounter = 1;
      await _saveSerialCounter();
      return;
    }

    final lastDateStr = prefs.getString(_keyLastDate);
    final currentDate = DateFormat('dd-MMM-yyyy').format(DateTime.now());

    if (lastDateStr != currentDate) {
      _serialCounter = 1;
      await _saveSerialCounter();
      await prefs.setString(_keyLastDate, currentDate);
      debugPrint('📅 [VM] New day - serial counter reset to 1');
      return;
    }

    debugPrint('🔢 [VM] Fetching max serial from server for emp_id=$empId, company=$companyCode');

    try {
      final maxSerial = await _repo.fetchMaxSerialFromServer(
        empId: empId,
        companyCode: companyCode,
      );

      _serialCounter = maxSerial + 1;
      await _saveSerialCounter();

      debugPrint('✅ [VM] Serial counter initialized: max=$maxSerial → next=$_serialCounter');
    } catch (e) {
      debugPrint('⚠️ [VM] Failed to fetch from server, using local counter: $e');
      _serialCounter = prefs.getInt('attendanceSerialCounter') ?? 1;
    }
  }

  Future<void> _restoreSerialCounterFromServer(String empId, String companyCode) async {
    try {
      final maxSerial = await _repo.fetchMaxSerialFromServer(
        empId: empId,
        companyCode: companyCode,
      );

      _serialCounter = maxSerial + 1;
      await _saveSerialCounter();

      debugPrint('✅ [VM] Serial counter restored: max=$maxSerial → next=$_serialCounter');
    } catch (e) {
      debugPrint('⚠️ [VM] Could not restore serial counter: $e');
    }
  }

  Future<void> _checkAndResetSerialCounter() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString(_keyLastDate);
    final currentDate = DateFormat('dd-MMM-yyyy').format(DateTime.now());

    if (lastDateStr != currentDate) {
      _serialCounter = 1;
      await _saveSerialCounter();
      await prefs.setString(_keyLastDate, currentDate);
      debugPrint('📅 [VM] New day detected! Reset serial counter to 1');
      return;
    }

    final String? empId = prefs.getString(prefUserId);
    final String? companyCode = DBHelper.getCompanyCode();

    if (empId != null && companyCode != null) {
      try {
        final maxSerial = await _repo.fetchMaxSerialFromServer(
          empId: empId,
          companyCode: companyCode,
        );

        final expectedNext = maxSerial + 1;
        if (expectedNext > _serialCounter) {
          debugPrint('⚠️ [VM] Server has higher serial ($maxSerial) than local ($_serialCounter) - syncing');
          _serialCounter = expectedNext;
          await _saveSerialCounter();
        }
      } catch (e) {
        debugPrint('⚠️ [VM] Could not verify with server: $e');
      }
    }

    debugPrint('📅 [VM] Same day, counter: $_serialCounter');
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
    String empId = '',
    String empName = '',
    String job = '',
    String city = '',
    Uint8List? photoBytes,
  }) async {
    await clockIn(
      empId: empId,
      empName: empName,
      job: job,
      city: city,
      photoBytes: photoBytes,
    );
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
    String empId = '',
    String empName = '',
    String job = '',
    String city = '',
    Uint8List? photoBytes,
  }) async {
    debugPrint('🎯 [VM] ===== CLOCK-IN STARTED =====');
    debugPrint('📸 [VM] photoBytes received: ${photoBytes != null ? "${photoBytes.length} bytes" : "NULL"}');

    await _checkAndResetSerialCounter();

    if (empId.isEmpty || empName.isEmpty || job.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      if (empId.isEmpty) empId = _safeReadString(prefs, 'emp_id');
      if (empName.isEmpty) empName = _safeReadStringFallback(prefs, ['emp_name', 'empName', 'employee_name', 'name', 'userName', 'user_name']);
      if (job.isEmpty) job = _safeReadStringFallback(prefs, ['job', 'designation', 'role', 'emp_job', 'position', 'jobTitle']);
      if (city.isEmpty) city = _safeReadStringFallback(prefs, ['city', 'emp_city', 'location']);
      debugPrint('👤 [VM] Resolved from prefs — empId=$empId | empName=$empName | job=$job | city=$city');
    }

    if (isClockedIn.value) {
      Get.snackbar('Already Clocked In', 'You are already clocked in',
          snackPosition: SnackPosition.TOP, backgroundColor: Colors.green);
      return;
    }

    if (!await _isLocationServiceOn()) {
      Get.snackbar('Location Required', 'Please turn on device location',
          backgroundColor: Colors.red);
      return;
    }

    String attendanceId = _buildAttendanceId(empId: empId);

    if (await _idExistsInDb(attendanceId)) {
      _serialCounter++;
      await _saveSerialCounter();
      attendanceId = _buildAttendanceId(empId: empId);
      debugPrint('🔄 [VM] Duplicate found — regenerated: $attendanceId');
    }

    _clockInTime = DateTime.now();
    isClockedIn.value = true;
    elapsedTime.value = '00:00:00';
    _startTimer();

    Get.snackbar('Clock-In Successful', 'You are now clocked in',
        backgroundColor: Colors.green);
    debugPrint('✅ [VM] Clock-in set. ID: $attendanceId');

    await _handleBackgroundTasks(
      attendanceId: attendanceId,
      empId: empId,
      empName: empName,
      job: job,
      city: city,
      photoBytes: photoBytes,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – ATD ID BUILDER
  // ─────────────────────────────────────────────────────────────────────────
  String _buildAttendanceId({required String empId}) {
    final now = DateTime.now();
    final day = DateFormat('dd').format(now);
    final month = DateFormat('MMM').format(now);
    final serial = _serialCounter.toString().padLeft(3, '0');
    final empPart = empId.padLeft(2, '0');

    final String companyCode = DBHelper.getCompanyCode() ?? '';

    String id;
    if (companyCode.isNotEmpty) {
      id = '$companyCode-ATD-EMP-$empPart-$day-$month-$serial';
    } else {
      id = 'ATD-EMP-$empPart-$day-$month-$serial';
    }

    debugPrint('🆔 Generated ID: $id (counter: $_serialCounter, company: $companyCode)');
    return id;
  }

  Future<bool> _idExistsInDb(String id) async {
    try {
      return await _repo.idExists(id);
    } catch (e) {
      debugPrint('❌ [VM] _idExistsInDb error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – FETCH / ADD / DELETE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> fetchAllAttendance() async {
    try {
      final records = await _repo.getAll();
      allAttendance.value = records;
    } catch (e) {
      debugPrint('⚠️ [VM] fetchAllAttendance failed: $e');
    }
  }

  Future<void> addAttendance(AttendanceModel model) async {
    await _repo.add(model);
    try {
      await fetchAllAttendance();
    } catch (e) {
      debugPrint('⚠️ [VM] addAttendance – fetchAll failed: $e');
    }
  }

  Future<void> deleteAttendance(String id) async {
    await _repo.delete(id);
    try {
      await fetchAllAttendance();
    } catch (e) {
      debugPrint('⚠️ [VM] deleteAttendance – fetchAll failed: $e');
    }
  }

  Future<void> syncNow() async {
    final status = await _internetStatus();
    if (status != 'none') {
      debugPrint('🌐 [VM] Manual sync triggered');
      await _repo.syncUnpostedWithBytes(_uploadBytesCache);
      _uploadBytesCache.clear();
      try {
        await fetchAllAttendance();
      } catch (e) {
        debugPrint('⚠️ [VM] syncNow – fetchAll failed: $e');
      }
    } else {
      debugPrint('🌐 [VM] No internet – sync skipped');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – CLOCK-IN STATE HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  Future<String?> getCurrentAttendanceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrentId) ??
        prefs.getString(_keyAttendanceId) ??
        prefs.getString('clockInAttendanceId');
  }

  Future<void> clearClockInState() async {
    _stopTimer();
    isClockedIn.value = false;
    _clockInTime = null;
    elapsedTime.value = '00:00:00';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyClockInTime);
    await prefs.remove(_keyTotalTime);
    await prefs.setInt(_keySecondsPassed, 0);
    await prefs.setBool(_keyIsClockedIn, false);

    final currentId = prefs.getString(_keyCurrentId);
    if (currentId != null) {
      await prefs.setString('usedAttendanceId', currentId);
      await prefs.remove(_keyCurrentId);
    }

    debugPrint('🔄 [VM] Clock-in state cleared');
  }

  Future<Map<String, dynamic>> getAttendanceStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final currentId = prefs.getString(_keyCurrentId);
    final clockInTime = prefs.getString(_keyClockInTime);
    final isClockedInS = prefs.getBool(_keyIsClockedIn) ?? false;

    bool idInDb = false;
    int totalRecords = 0;
    try {
      final allRecords = await _repo.getAll();
      totalRecords = allRecords.length;
      idInDb = currentId != null && allRecords.any((r) => r.attendance_in_id == currentId);
    } catch (_) {}

    return {
      'currentId': currentId,
      'clockInTime': clockInTime,
      'isClockedIn': isClockedInS,
      'totalRecords': totalRecords,
      'idExistsInDB': idInDb,
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
      final seen = <String>{};
      final toDelete = <String>[];

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

    final prefs = await SharedPreferences.getInstance();
    final isClockedInS = prefs.getBool(_keyIsClockedIn) ?? false;
    final clockInTime = prefs.getString(_keyClockInTime);

    if (isClockedInS && clockInTime == null) {
      debugPrint('⚠️ [VM] Inconsistent state – resetting');
      await prefs.setBool(_keyIsClockedIn, false);
    }

    final allRecords = await _repo.getAll();
    final currentId = prefs.getString(_keyCurrentId);
    if (currentId != null && !allRecords.any((r) => r.attendance_in_id == currentId)) {
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
    Uint8List? photoBytes,
  }) async {
    debugPrint('🛰 [VM] Background tasks started...');

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_keyClockInTime, _clockInTime!.toIso8601String());
      await prefs.setString(_keyCurrentId, attendanceId);
      await prefs.setString(_keyAttendanceId, attendanceId);
      await prefs.setString('clockInAttendanceId', attendanceId);
      await prefs.setBool(_keyIsClockedIn, true);
      await prefs.setInt(_keySecondsPassed, 0);
      await prefs.remove(_keyTotalTime);

      final gps = await _getValidGPS();
      final lat = gps['lat']!;
      final lng = gps['lng']!;

      final String selectedLocAddress = prefs.getString('selected_location_address') ?? '';
      final String selectedLocationName = prefs.getString('selected_location_name') ?? '';
      String address = selectedLocAddress.isNotEmpty
          ? selectedLocAddress
          : _locationVM.shopAddress.value;

      if (address.isEmpty) {
        debugPrint('📍 [VM] No pre-set address — reverse-geocoding $lat,$lng');
        address = await _reverseGeocode(lat, lng);
      }

      final DateTime clockInNow = _clockInTime ?? DateTime.now();

      String? profileBase64;
      if (photoBytes != null && photoBytes.isNotEmpty) {
        try {
          final Uint8List? compressed = await _compressForStorage(photoBytes);
          final Uint8List storageBytes = compressed ?? photoBytes;
          profileBase64 = base64Encode(storageBytes);
          _uploadBytesCache[attendanceId] = photoBytes;
          debugPrint('📸 [VM] Profile compressed: ${photoBytes.length} B → ${storageBytes.length} B');
        } catch (e) {
          debugPrint('❌ [VM] base64Encode FAILED: $e');
          profileBase64 = null;
        }
      }

      final String companyCode = DBHelper.getCompanyCode() ?? '';
      debugPrint('🏢 [VM] company_code: "$companyCode"');

      final model = AttendanceModel(
        attendance_in_id: attendanceId,
        emp_id: empId,
        emp_name: empName,
        job: job,
        lat_in: lat.toString(),
        lng_in: lng.toString(),
        city: city,
        address: address,
        location_name: selectedLocationName,
        attendance_in_date: clockInNow,
        attendance_in_time: clockInNow,
        profile: profileBase64,
        company_code: companyCode,
        posted: 0,
      );
      await addAttendance(model);
      debugPrint('✅ [VM] Saved to local DB: $attendanceId');

      _serialCounter++;
      await _saveSerialCounter();
      debugPrint('🔢 [VM] Serial counter after increment: $_serialCounter');

      final status = await _internetStatus().timeout(
        const Duration(seconds: 3),
        onTimeout: () => 'none',
      );

      if (status != 'none') {
        debugPrint('🌐 [VM] Syncing to server...');
        await _repo.syncUnpostedWithBytes(_uploadBytesCache);
        try {
          await fetchAllAttendance();
        } catch (_) {}
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
  Future<String> _reverseGeocode(double lat, double lng) async {
    if (lat == 0.0 && lng == 0.0) return '';
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng',
      );
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'GPSWorkforceMonitor/1.0',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['display_name']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('⚠️ [VM] Reverse geocode failed: $e');
    }
    return '';
  }

  Future<bool> _isLocationServiceOn() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return true;
    }
  }

  Future<Map<String, double>> _getValidGPS() async {
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

    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final lat = _locationVM.globalLatitude1.value;
      final lng = _locationVM.globalLongitude1.value;
      if (lat != 0.0 || lng != 0.0) {
        debugPrint('✅ [GPS] From LocationViewModel: $lat, $lng');
        return {'lat': lat, 'lng': lng};
      }
    }

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && (last.latitude != 0.0 || last.longitude != 0.0)) {
        debugPrint('✅ [GPS] Last known: ${last.latitude}, ${last.longitude}');
        return {'lat': last.latitude, 'lng': last.longitude};
      }
    } catch (e) {
      debugPrint('⚠️ [GPS] getLastKnownPosition failed: $e');
    }

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
    final prefs = await SharedPreferences.getInstance();
    final clockInString = prefs.getString(_keyClockInTime);

    if (clockInString != null) {
      _clockInTime = DateTime.parse(clockInString);
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

  String _safeReadString(SharedPreferences prefs, String key) {
    try {
      final dynamic raw = prefs.get(key);
      if (raw == null) return '';
      return raw.toString();
    } catch (_) {
      return '';
    }
  }

  String _safeReadStringFallback(SharedPreferences prefs, List<String> keys) {
    for (final key in keys) {
      try {
        final dynamic raw = prefs.get(key);
        if (raw != null) {
          final String val = raw.toString().trim();
          if (val.isNotEmpty) {
            return val;
          }
        }
      } catch (_) {}
    }
    return '';
  }

  Future<void> _saveTotalTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTotalTime, time);
  }

  Future<Uint8List?> _compressForStorage(Uint8List original) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        original,
        targetWidth: 60,
        targetHeight: 60,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('❌ [VM] _compressForStorage error: $e');
      return null;
    }
  }

  Future<String> generateAttendanceId(String empId) async {
    await _checkAndResetSerialCounter();
    String attendanceId = _buildAttendanceId(empId: empId);

    while (await _idExistsInDb(attendanceId)) {
      _serialCounter++;
      await _saveSerialCounter();
      attendanceId = _buildAttendanceId(empId: empId);
    }

    debugPrint('🆔 [VM] Generated attendance ID: $attendanceId');
    return attendanceId;
  }
}