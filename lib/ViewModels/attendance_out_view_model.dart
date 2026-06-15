import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../Database/db_helper.dart';
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
  // PRIVATE - Reverse Geocoding Helper
  // ─────────────────────────────────────────────────────────────────────────

  /// Convert latitude and longitude to human-readable address
  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;

        final List<String> addressParts = [];

        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
          addressParts.add(place.subAdministrativeArea!);
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }

        if (addressParts.isEmpty) {
          if (place.name != null && place.name!.isNotEmpty) {
            return place.name!;
          }
          return '$lat, $lng';
        }

        return addressParts.join(', ');
      }

      return '$lat, $lng';
    } catch (e) {
      debugPrint('❌ [OutVM Geocoding] Error: $e');
      return '$lat, $lng';
    }
  }

  /// Get location name from SharedPreferences (for geofencing users)
  Future<String> _getLocationName() async {
    final prefs = await SharedPreferences.getInstance();
    // Get the selected location name from geofencing selection
    final locationName = prefs.getString('selected_location_name');
    if (locationName != null && locationName.isNotEmpty) {
      debugPrint('📍 [OutVM] Geofencing location name: $locationName');
      return locationName;
    }
    debugPrint('📍 [OutVM] Normal user - no location name');
    return '';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – Image compression
  // Oracle PL/SQL VARCHAR2 max = 32,767 bytes. Base64 adds ~33% overhead.
  // Target: ≤ 18,000 raw bytes → ≤ 24,000 base64 chars (safe buffer).
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> _compressAndEncodeImage(Uint8List? photoBytes) async {
    if (photoBytes == null || photoBytes.isEmpty) return null;

    const int targetBytes  = 18000;
    const int maxDimension = 400;

    try {
      Uint8List compressed = await FlutterImageCompress.compressWithList(
        photoBytes,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: 60,
        format: CompressFormat.jpeg,
      );

      for (int q = 45; compressed.length > targetBytes && q >= 20; q -= 10) {
        compressed = await FlutterImageCompress.compressWithList(
          photoBytes,
          minWidth: maxDimension,
          minHeight: maxDimension,
          quality: q,
          format: CompressFormat.jpeg,
        );
        debugPrint('📸 [OutVM] Compress attempt q=$q → ${compressed.length} bytes');
      }

      final encoded = base64Encode(compressed);
      debugPrint('📸 [OutVM] Image compressed: ${photoBytes.length} → ${compressed.length} bytes '
          '| base64: ${encoded.length} chars');
      return encoded;
    } catch (e) {
      debugPrint('⚠️ [OutVM] Compression failed, skipping image: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – PRIMARY CLOCK-OUT (UPDATED with custom parameters)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> clockOut({
    required String empId,
    DateTime? clockOutTime,
    double? totalDistance,
    bool isAuto = false,
    String reason = 'manual',
    String? customLocationName,  // ✅ NEW - for custom location name from travel
    String? customAddress,       // ✅ NEW - for custom address from travel
    String? clockOutImage,       // ✅ FIX - restored base64 image from fast data
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final DateTime outTime = clockOutTime ?? DateTime.now();

    debugPrint('🕐 [OutVM] Clock-out time: ${DateFormat('hh:mm:ss a').format(outTime)}');
    debugPrint('📱 [OutVM] Device time:    ${DateFormat('hh:mm:ss a').format(DateTime.now())}');
    debugPrint('🤖 [OutVM] Auto: $isAuto, Reason: $reason');

    final String? clockInStr = prefs.getString(_keyClockInTime);
    DateTime shiftStart;
    if (clockInStr != null && clockInStr.isNotEmpty) {
      try {
        shiftStart = DateTime.parse(clockInStr);
      } catch (e) {
        debugPrint('⚠️ [OutVM] clockOut — DateTime.parse failed for clockInStr="$clockInStr": $e');
        shiftStart = outTime.subtract(const Duration(hours: 1));
      }
    } else {
      debugPrint('⚠️ [OutVM] clockOut — clockInStr is null/empty; falling back to outTime - 1h');
      shiftStart = outTime.subtract(const Duration(hours: 1));
    }
    debugPrint('🕐 [OutVM] clockOut shiftStart=$shiftStart | outTime=$outTime | diff=${outTime.difference(shiftStart)}');
    final String totalTime = _formatDuration(outTime.difference(shiftStart));

    final double finalDistance = await _resolveDistance(
      provided: totalDistance,
      prefs: prefs,
      shiftStart: shiftStart,
    );

    // ✅ USE THE SAME ATTENDANCE IN ID - NO CONVERSION
    String attendanceOutId = prefs.getString(_keyAttendanceId)
        ?? prefs.getString(_keyCurrentId)
        ?? prefs.getString(_keyClockInAltId)
        ?? '';

    if (attendanceOutId.isEmpty) {
      attendanceOutId = 'UNKWN_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('⚠️ [OutVM] No attendanceId found — using fallback: $attendanceOutId');
    } else {
      debugPrint('✅ [OutVM] Using same ID as attendance IN: $attendanceOutId');
    }

    // ✅ Get location name (use custom if provided, otherwise get from prefs)
    String locationName = customLocationName ?? await _getLocationName();

    // ✅ Get address (use custom if provided, otherwise get from geocoding)
    String humanAddress = customAddress ?? '';

    // If no custom address, get from geocoding
    if (humanAddress.isEmpty) {
      double currentLat = _locVM.globalLatitude1.value;
      double currentLng = _locVM.globalLongitude1.value;

      try {
        final currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        ).timeout(const Duration(seconds: 7));
        currentLat = currentPosition.latitude;
        currentLng = currentPosition.longitude;
        humanAddress = await _getAddressFromLatLng(currentLat, currentLng);
      } catch (e) {
        debugPrint('⚠️ [OutVM] Using cached location for geocoding: $e');
        humanAddress = _locVM.shopAddress.value;
      }
    }

    String address = humanAddress;
    if (isAuto && !address.contains('Auto clock-out')) {
      address = '$humanAddress (Auto clock-out: $reason at ${DateFormat('hh:mm a').format(outTime)})';
    }

    await _saveBackup(
      attendanceOutId: attendanceOutId,
      empId: empId,
      clockOutTime: outTime,
      totalTime: totalTime,
      totalDistance: finalDistance,
      address: address,
      reason: reason,
      locationName: locationName,
      clockOutImage: clockOutImage,  // ✅ FIX — pass image to backup
    );

    final model = AttendanceOutModel(
      attendance_out_id: attendanceOutId,
      emp_id: empId,
      total_time: totalTime,
      total_distance: finalDistance.toString(),
      lat_out: _locVM.globalLatitude1.value.toString(),
      lng_out: _locVM.globalLongitude1.value.toString(),
      address: address,
      location_name: locationName,
      reason: reason,
      attendance_out_time: outTime,
      attendance_out_date: outTime,
      posted: 0,
      company_code: DBHelper.getCompanyCode(),
      clock_out_image: clockOutImage,  // ✅ FIX - restored image from fast data
    );

    debugPrint('📊 [OutVM] Clock-out data:');
    debugPrint('   - ID: $attendanceOutId');
    debugPrint('   - Distance: ${finalDistance.toStringAsFixed(3)} km');
    debugPrint('   - Time: $totalTime');
    debugPrint('   - Reason: $reason');
    debugPrint('   - Location Name: ${locationName.isEmpty ? "(empty - normal user)" : locationName}');
    debugPrint('   - Address: $humanAddress');

    await addAttendanceOut(model);
    await _postIfOnline(prefs);
    await _inVM.clearClockInState();

    debugPrint('✅ [OutVM] Clock-out complete.');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – FAST CLOCK-OUT (< 1 second, UI unblocked)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> fastSaveAttendanceOut({
    String empId = '',
    required DateTime clockOutTime,
    required double totalDistance,
    bool isAuto = false,
    String reason = 'fast_manual',
    String? customLocationName,  // ✅ NEW
    String? customAddress,       // ✅ NEW
    Uint8List? photoBytes,       // ✅ NEW — clock-out selfie
    String? clockInTimeStr,      // ✅ FIX — pre-captured clockInTime before prefs were cleared
  }) async {
    // ✅ Compress before encoding — keeps base64 under Oracle VARCHAR2 limit (32,767 bytes)
    final String? clockOutImageBase64 = await _compressAndEncodeImage(photoBytes);

    debugPrint('⚡ [OutVM] Fast clock-out started');

    final prefs = await SharedPreferences.getInstance();

    final String resolvedEmpId = empId.isNotEmpty ? empId : (prefs.getString('emp_id') ?? '');

    double latOut = _locVM.globalLatitude1.value;
    double lngOut = _locVM.globalLongitude1.value;
    String humanAddress = customAddress ?? _locVM.shopAddress.value;

    if (customAddress == null) {
      try {
        final currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        ).timeout(const Duration(seconds: 7));

        latOut = currentPosition.latitude;
        lngOut = currentPosition.longitude;
        _locVM.globalLatitude1.value = latOut;
        _locVM.globalLongitude1.value = lngOut;

        humanAddress = await _getAddressFromLatLng(latOut, lngOut);
        _locVM.shopAddress.value = humanAddress;

        debugPrint('📍 [OutVM Fast] Fresh location: $latOut, $lngOut');
        debugPrint('📍 [OutVM Fast] Address: $humanAddress');
      } catch (e) {
        debugPrint('⚠️ [OutVM Fast] Using cached location: $e');
      }
    }

    // ✅ Get location name (use custom if provided)
    final String locationName = customLocationName ?? await _getLocationName();

    // ✅ USE THE SAME ATTENDANCE IN ID - NO CONVERSION
    String attendanceOutId = prefs.getString(_keyAttendanceId)
        ?? prefs.getString(_keyCurrentId)
        ?? prefs.getString(_keyClockInAltId)
        ?? '';

    if (attendanceOutId.isEmpty) {
      attendanceOutId = 'FAST_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('fastAttendanceId', attendanceOutId);
      debugPrint('⚠️ [OutVM Fast] Generated fallback ID: $attendanceOutId');
    } else {
      debugPrint('✅ [OutVM Fast] Using same ID as attendance IN: $attendanceOutId');
    }

    // ✅ FIX: Prefer the pre-captured clockInTimeStr (passed from timer_card before
    // clearClockInState() wiped the pref). Only fall back to prefs if not provided.
    final String? resolvedClockInStr = clockInTimeStr ?? prefs.getString(_keyClockInTime);
    String totalTime = '00:00:00';
    if (resolvedClockInStr != null && resolvedClockInStr.isNotEmpty) {
      try {
        totalTime = _formatDuration(clockOutTime.difference(DateTime.parse(resolvedClockInStr)));
      } catch (e) {
        debugPrint('⚠️ [OutVM Fast] DateTime.parse failed for clockInStr="$resolvedClockInStr": $e');
        debugPrint('⚠️ [OutVM Fast] totalTime will remain 00:00:00 — check how clockInTime is stored');
      }
    } else {
      debugPrint('⚠️ [OutVM Fast] clockInStr is null/empty — totalTime stays 00:00:00');
    }
    debugPrint('🕐 [OutVM Fast] clockInStr=$resolvedClockInStr | clockOutTime=$clockOutTime | totalTime=$totalTime');

    final Map<String, dynamic> fastData = {
      'fast_attendanceId': attendanceOutId,
      'fast_empId': resolvedEmpId,
      'fast_clockOutTime': clockOutTime.toIso8601String(),
      'fast_totalTime': totalTime,
      'fast_totalDistance': totalDistance,
      'fast_latOut': latOut,
      'fast_lngOut': lngOut,
      'fast_address': humanAddress,
      'fast_location_name': locationName,
      'fast_reason': reason,
      'fast_savedAt': DateTime.now().millisecondsSinceEpoch.toString(),
      'fast_company_code': DBHelper.getCompanyCode(),
      if (clockOutImageBase64 != null) 'fast_clock_out_image': clockOutImageBase64,
    };

    await prefs.setString(_keyFastData, jsonEncode(fastData));
    await prefs.setBool(_keyHasFastData, true);
    await prefs.setDouble(_keyClockOutDistance, totalDistance);
    await prefs.setString(_keyFastClockOutTime, clockOutTime.toIso8601String());
    await prefs.setDouble(_keyFastClockOutDist, totalDistance);
    await prefs.setString(_keyFastClockOutReason, reason);

    debugPrint('⚡ [OutVM] Fast data persisted. ID: $attendanceOutId');
    debugPrint('📍 [OutVM Fast] Location Name: ${locationName.isEmpty ? "(empty - normal user)" : locationName}');
    debugPrint('📍 [OutVM Fast] Reason: $reason');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final model = AttendanceOutModel(
          attendance_out_id: attendanceOutId,
          emp_id: resolvedEmpId,
          total_time: totalTime,
          total_distance: totalDistance.toString(),
          lat_out: latOut.toString(),
          lng_out: lngOut.toString(),
          address: humanAddress,
          location_name: locationName,
          reason: reason,
          attendance_out_time: clockOutTime,
          attendance_out_date: clockOutTime,
          posted: 0,
          company_code: DBHelper.getCompanyCode(),
          clock_out_image: clockOutImageBase64,  // ✅ NEW — clock-out selfie
        );

        await addAttendanceOut(model);
        debugPrint('⚡ [OutVM] Fast DB save done with id=$attendanceOutId');

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
    debugPrint('   - ID: $attendanceOutId | Distance: ${totalDistance.toStringAsFixed(3)} km');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – DIRECT SAVE WITH DISTANCE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> saveWithDistance({
    required String empId,
    required String attendanceOutId,
    required double distance,
    required DateTime clockOutTime,
    String address = '',
    bool isAuto = false,
    String? customLocationName,  // ✅ NEW
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? clockInStr = prefs.getString(_keyClockInTime);
    final DateTime shiftStart = clockInStr != null
        ? DateTime.parse(clockInStr)
        : clockOutTime.subtract(const Duration(hours: 1));
    final String totalTime = _formatDuration(clockOutTime.difference(shiftStart));

    // ✅ Get location name (use custom if provided)
    final String locationName = customLocationName ?? await _getLocationName();

    // ✅ Get address if not provided
    String finalAddress = address;
    if (finalAddress.isEmpty) {
      double lat = _locVM.globalLatitude1.value;
      double lng = _locVM.globalLongitude1.value;
      finalAddress = await _getAddressFromLatLng(lat, lng);
    }

    if (isAuto) {
      finalAddress = '$finalAddress (Auto clock-out at ${DateFormat('hh:mm a').format(clockOutTime)})';
    }

    final model = AttendanceOutModel(
      attendance_out_id: attendanceOutId,
      emp_id: empId,
      total_time: totalTime,
      total_distance: distance.toString(),
      lat_out: _locVM.globalLatitude1.value.toString(),
      lng_out: _locVM.globalLongitude1.value.toString(),
      address: finalAddress,
      location_name: locationName,
      reason: isAuto ? 'direct_auto' : 'direct_manual',
      attendance_out_time: clockOutTime,
      attendance_out_date: clockOutTime,
      posted: 0,
      company_code: DBHelper.getCompanyCode(),
    );

    await addAttendanceOut(model);
    await _saveBackup(
      attendanceOutId: attendanceOutId,
      empId: empId,
      clockOutTime: clockOutTime,
      totalTime: totalTime,
      totalDistance: distance,
      address: finalAddress,
      reason: model.reason ?? (isAuto ? 'direct_auto' : 'direct_manual'),
      locationName: locationName,
    );
    await _postIfOnline(prefs);

    debugPrint('✅ [OutVM] saveWithDistance done: ${distance.toStringAsFixed(3)} km, ID: $attendanceOutId');
    debugPrint('📍 [OutVM] Location Name: ${locationName.isEmpty ? "(empty - normal user)" : locationName}');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – LEGACY ALIAS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> saveFormAttendanceOut({DateTime? clockOutTime}) async {
    final prefs = await SharedPreferences.getInstance();
    final empId = prefs.getString('emp_id') ?? '';
    await clockOut(
      empId: empId,
      clockOutTime: clockOutTime,
      isAuto: clockOutTime != null,
      reason: clockOutTime != null ? 'legacy_auto' : 'manual',
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
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final timeStr = data['backup_clockOutTime'] as String?;

      debugPrint('🔄 [OutVM] Restoring backup...');
      debugPrint('   - ID: ${data['backup_attendanceId']} | Reason: ${data['backup_reason']}');
      debugPrint('   - Distance: ${data['backup_totalDistance']} km');

      if (timeStr != null) {
        final realTime = DateTime.parse(timeStr);
        final dist = (data['backup_totalDistance'] as num?)?.toDouble() ?? 0.0;
        final reason = data['backup_reason'] as String? ?? 'backup_restored';
        final empId = data['backup_empId'] as String? ?? '';
        final locationName = data['backup_location_name'] as String?;
        final address = data['backup_address'] as String?;
        final restoredClockOutImage = data['backup_clock_out_image'] as String?;  // ✅ FIX

        debugPrint('✅ [OutVM] Restore with real time=$realTime');
        debugPrint('📸 [OutVM] Backup restore image: ${restoredClockOutImage != null ? "✅ (${restoredClockOutImage.length} chars)" : "❌ NULL"}');  // ✅ FIX

        await clockOut(
          empId: empId,
          clockOutTime: realTime,
          totalDistance: dist,
          isAuto: true,
          reason: reason,
          customLocationName: locationName,
          customAddress: address,
          clockOutImage: restoredClockOutImage,  // ✅ FIX
        );

        await prefs.setBool(_keyHasBackup, false);
        await prefs.remove(_keyBackupData);
        await prefs.remove(_keyBackupDistance);
        debugPrint('✅ [OutVM] Backup restored');
      }
    } catch (e) {
      debugPrint('❌ [OutVM] restoreFromBackupIfNeeded error: $e');
    }
  }

  Future<void> restoreFastDataOnStartup() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_keyHasFastData) ?? false)) return;

    if (prefs.getBool(_keyCriticalEvent) ?? false) {
      debugPrint('⏭️ [OutVM] Critical event pending — skipping fast restore');
      return;
    }

    debugPrint('🔄 [OutVM] Restoring fast clock-out data...');
    try {
      String? timeStr = prefs.getString(_keyFastClockOutTime);
      String? locationName;
      String? address;

      if (timeStr == null) {
        final blob = prefs.getString(_keyFastData) ?? '{}';
        final Map<String, dynamic> data = jsonDecode(blob);
        timeStr = data['fast_clockOutTime'] as String?;
        locationName = data['fast_location_name'] as String?;
        address = data['fast_address'] as String?;
      }

      if (timeStr == null || timeStr.isEmpty) {
        debugPrint('⚠️ [OutVM] No valid fast timestamp — skipping restore');
        return;
      }

      double dist = prefs.getDouble(_keyFastClockOutDist) ?? 0.0;
      if (dist == 0.0) {
        final blob = prefs.getString(_keyFastData) ?? '{}';
        dist = ((jsonDecode(blob) as Map<String, dynamic>)['fast_totalDistance'] as num?)?.toDouble() ?? 0.0;
      }

      final String reason = prefs.getString(_keyFastClockOutReason) ?? 'background_auto';
      final DateTime realTime = DateTime.parse(timeStr);

      String empId = '';
      String? restoredClockOutImage;  // ✅ FIX
      try {
        final blob = jsonDecode(prefs.getString(_keyFastData) ?? '{}') as Map<String, dynamic>;
        empId = blob['fast_empId'] as String? ?? '';
        restoredClockOutImage = blob['fast_clock_out_image'] as String?;  // ✅ FIX
      } catch (_) {}

      debugPrint('✅ [OutVM] Fast restore: time=$realTime, dist=$dist km');
      debugPrint('📸 [OutVM] Fast restore image: ${restoredClockOutImage != null ? "✅ (${restoredClockOutImage.length} chars)" : "❌ NULL (auto clockout)"}');  // ✅ FIX

      await clockOut(
        empId: empId,
        clockOutTime: realTime,
        totalDistance: dist,
        isAuto: true,
        reason: reason,
        customLocationName: locationName,
        customAddress: address,
        clockOutImage: restoredClockOutImage,  // ✅ FIX
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
          '📊 ID=${r.attendance_out_id} | dist=${r.total_distance} km | time=${r.total_time} | posted=${r.posted} | company=${r.company_code} | location_name=${r.location_name} | reason=${r.reason}');
    }
  }

  Future<int> todayClockOutsCount() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final records = await _repo.getAll();
    return records
        .where((r) => r.attendance_out_date?.toString().contains(today) ?? false)
        .length;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – AUTO CLOCK-OUT TIMER
  // ─────────────────────────────────────────────────────────────────────────

  void _startAutoClockOutTimer() {
    debugPrint('⏰ [OutVM] Starting auto clock-out timer for 11:58 PM');
    _autoClockOutTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkAutoClockOut());
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
        empId: empId,
        clockOutTime: DateTime(now.year, now.month, now.day, 23, 58, 0),
        isAuto: true,
        reason: '11:58_pm_auto',
      );

      Get.snackbar(
        'Auto Clock-Out',
        'Automatically clocked out at 11:58 PM',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.purple.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 10),
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
      return results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
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
    required String attendanceOutId,
    required String empId,
    required DateTime clockOutTime,
    required String totalTime,
    required double totalDistance,
    required String address,
    required String reason,
    String? locationName,
    String? clockOutImage,  // ✅ FIX — persist image in backup
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final finalLocationName = locationName ?? await _getLocationName();
    final data = {
      'backup_attendanceId': attendanceOutId,
      'backup_empId': empId,
      'backup_clockOutTime': clockOutTime.toIso8601String(),
      'backup_totalTime': totalTime,
      'backup_totalDistance': totalDistance,
      'backup_latOut': _locVM.globalLatitude1.value,
      'backup_lngOut': _locVM.globalLongitude1.value,
      'backup_address': address,
      'backup_location_name': finalLocationName,
      'backup_reason': reason,
      'backup_savedAt': DateTime.now().toIso8601String(),
      'backup_company_code': DBHelper.getCompanyCode(),
      if (clockOutImage != null) 'backup_clock_out_image': clockOutImage,  // ✅ FIX
    };
    await prefs.setString(_keyBackupData, jsonEncode(data));
    await prefs.setBool(_keyHasBackup, true);
    await prefs.setDouble(_keyBackupDistance, totalDistance);
    debugPrint('📱 [OutVM] Backup saved: ${totalDistance.toStringAsFixed(3)} km, location: $finalLocationName, reason: $reason');
    debugPrint('📸 [OutVM] Backup image: ${clockOutImage != null ? "✅ (${clockOutImage.length} chars)" : "❌ NULL (auto/no-selfie)"}');  // ✅ FIX
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

  String _getStringFromPrefs(SharedPreferences prefs, String key) {
    try {
      return prefs.getString(key) ?? '';
    } catch (_) {
      return '';
    }
  }
}