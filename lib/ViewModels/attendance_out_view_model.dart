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
import '../Services/battery_consumption_service.dart'; // ✅ NEW

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
    String? customLocationName,
    String? customAddress,
    String? clockOutImage,
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

    // ✅ Battery consumption tracking
    final int batteryUsed = await BatteryConsumptionService.getBatteryUsed();
    await BatteryConsumptionService.clearClockInBattery();
    debugPrint('🔋 [OutVM] Battery used this shift: $batteryUsed%');

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
      clockOutImage: clockOutImage,
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
      clock_out_image: clockOutImage,
      battery_used: batteryUsed,  // ✅ NEW
    );

    debugPrint('📊 [OutVM] Clock-out data:');
    debugPrint('   - ID: $attendanceOutId');
    debugPrint('   - Distance: ${finalDistance.toStringAsFixed(3)} km');
    debugPrint('   - Time: $totalTime');
    debugPrint('   - Reason: $reason');
    debugPrint('   - Location Name: ${locationName.isEmpty ? "(empty - normal user)" : locationName}');
    debugPrint('   - Address: $humanAddress');
    debugPrint('   - Battery Used: $batteryUsed%');

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
    String? customLocationName,
    String? customAddress,
    Uint8List? photoBytes,
    String? clockInTimeStr,
  }) async {
    // ✅ Compress before encoding — keeps base64 under Oracle VARCHAR2 limit (32,767 bytes)
    final String? clockOutImageBase64 = await _compressAndEncodeImage(photoBytes);

    // ✅ Battery consumption tracking
    final int fastBatteryUsed = await BatteryConsumptionService.getBatteryUsed();
    await BatteryConsumptionService.clearClockInBattery();
    debugPrint('🔋 [OutVM Fast] Battery used this shift: $fastBatteryUsed%');

    debugPrint('⚡ [OutVM] Fast clock-out started');

    final prefs = await SharedPreferences.getInstance();

    // ✅ FIX #3: emp_id prefs mein setInt se save hota hai — getString() int par
    // TypeError throw karta tha jis se poora (unawaited) fastSave silently mar
    // jata tha aur clock-out DB tak save nahi hota tha. Type-safe read:
    final String resolvedEmpId =
    empId.isNotEmpty ? empId : _safeEmpIdFromPrefs(prefs);

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
      'fast_battery_used': fastBatteryUsed,  // ✅ NEW
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
    debugPrint('🔋 [OutVM Fast] Battery Used: $fastBatteryUsed%');

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
          clock_out_image: clockOutImageBase64,
          battery_used: fastBatteryUsed,  // ✅ NEW
        );

        await addAttendanceOut(model);
        debugPrint('⚡ [OutVM] Fast DB save done with id=$attendanceOutId');

        Timer(const Duration(seconds: 10), () async {
          if (await _isOnline()) {
            await _repo.syncUnposted();
            await fetchAllAttendanceOut();
            // ✅ FIX #5 (OutVM side): flags pehle sync ke result check kiye
            // baghair clear ho jate the — agar POST fail hota to restore
            // safety-net bhi khatam ho jata tha. Ab sirf tab clear karo jab
            // YEH record DB mein maujood ho aur posted=1 ho chuka ho.
            try {
              final bool stillUnposted = (await _repo.getUnposted()).any(
                    (r) => r.attendance_out_id?.toString() == attendanceOutId,
              );
              final bool savedInDb = await _repo.idExists(attendanceOutId);
              if (savedInDb && !stillUnposted) {
                await prefs.setBool(_keyHasFastData, false);
                await prefs.remove(_keyFastData);
                debugPrint('⚡ [OutVM] Delayed sync complete — flags cleared');
              } else {
                debugPrint('⏸️ [OutVM] Delayed sync: record not yet posted '
                    '(savedInDb=$savedInDb, stillUnposted=$stillUnposted) — flags KEPT for retry');
              }
            } catch (e) {
              debugPrint('⚠️ [OutVM] Delayed sync flag-check error (flags kept): $e');
            }
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
    String? customLocationName,
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
    // ✅ FIX #3: getString('emp_id') int-typed key par throw karta tha —
    // yeh poori method har call par crash ho jati thi. Type-safe read:
    final empId = _safeEmpIdFromPrefs(prefs);
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
      // ✅ FIX #5-spirit: conditional clear — failed sync par safety-net na uray.
      try {
        final remaining = await _repo.getUnposted();
        if (remaining.isEmpty) {
          await _clearBackupKeys(prefs);
          debugPrint('✅ [OutVM] Sync done — backup cleared');
        } else {
          debugPrint('⏸️ [OutVM] Sync done but ${remaining.length} still unposted — backup KEPT');
        }
      } catch (_) {
        debugPrint('⚠️ [OutVM] syncNow post-check failed — backup KEPT');
      }
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
        final restoredClockOutImage = data['backup_clock_out_image'] as String?;

        debugPrint('✅ [OutVM] Restore with real time=$realTime');
        debugPrint('📸 [OutVM] Backup restore image: ${restoredClockOutImage != null ? "✅ (${restoredClockOutImage.length} chars)" : "❌ NULL"}');

        await clockOut(
          empId: empId,
          clockOutTime: realTime,
          totalDistance: dist,
          isAuto: true,
          reason: reason,
          customLocationName: locationName,
          customAddress: address,
          clockOutImage: restoredClockOutImage,
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

      // ✅ FIX #4: getDouble() Kotlin ki raw-String value par throw karta tha
      // aur poora restore abort ho jata tha. Ab type-safe reader:
      double dist = _safeReadDouble(prefs, _keyFastClockOutDist);
      if (dist == 0.0) {
        try {
          final blob = prefs.getString(_keyFastData) ?? '{}';
          dist = ((jsonDecode(blob) as Map<String, dynamic>)['fast_totalDistance'] as num?)?.toDouble() ?? 0.0;
        } catch (_) {}
      }

      final String reason = _getStringFromPrefs(prefs, _keyFastClockOutReason).isNotEmpty
          ? _getStringFromPrefs(prefs, _keyFastClockOutReason)
          : 'background_auto';
      final DateTime realTime = DateTime.parse(timeStr);

      String empId = '';
      String? restoredClockOutImage;
      String blobAttendanceId = '';
      try {
        final blob = jsonDecode(prefs.getString(_keyFastData) ?? '{}') as Map<String, dynamic>;
        // ✅ FIX #4: Kotlin JSON mein key 'fast_userId' thi jabke Flutter
        // 'fast_empId' parhta tha → empId hamesha '' aata tha. Dono keys
        // support karo (Kotlin side bhi ab dono likhta hai):
        empId = (blob['fast_empId'] as String?) ??
            (blob['fast_userId'] as String?) ?? '';
        restoredClockOutImage = blob['fast_clock_out_image'] as String?;
        blobAttendanceId = (blob['fast_attendanceId'] as String?) ?? '';
      } catch (_) {}

      // ✅ FIX #3 (restore path): agar blob se empId nahi mila to prefs se
      // type-safe read karo — pehle yahan bhi '' chala jata tha.
      if (empId.isEmpty) {
        empId = _safeEmpIdFromPrefs(prefs);
      }

      // ✅ FIX #4: Kotlin ab fast_attendanceId bhi likhta hai. Agar prefs mein
      // attendance ID keys kisi wajah se missing hain (partial wipe waghaira)
      // to blob ki ID prefs mein seed kar do taake clockOut() UNKWN_ fallback
      // ki bajaye SAHI clock-in ID use kare. Yeh sirf tab hota hai jab prefs
      // mein koi ID maujood NA ho — existing behaviour override nahi hota.
      if (blobAttendanceId.isNotEmpty) {
        final String existingId = prefs.getString(_keyAttendanceId) ??
            prefs.getString(_keyCurrentId) ??
            prefs.getString(_keyClockInAltId) ?? '';
        if (existingId.isEmpty) {
          await prefs.setString(_keyAttendanceId, blobAttendanceId);
          debugPrint('🆔 [OutVM] FIX #4: blob attendanceId seeded into prefs: $blobAttendanceId');
        }
      }

      debugPrint('✅ [OutVM] Fast restore: time=$realTime, dist=$dist km');
      debugPrint('📸 [OutVM] Fast restore image: ${restoredClockOutImage != null ? "✅ (${restoredClockOutImage.length} chars)" : "❌ NULL (auto clockout)"}');

      await clockOut(
        empId: empId,
        clockOutTime: realTime,
        totalDistance: dist,
        isAuto: true,
        reason: reason,
        customLocationName: locationName,
        customAddress: address,
        clockOutImage: restoredClockOutImage,
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
          '📊 ID=${r.attendance_out_id} | dist=${r.total_distance} km | time=${r.total_time} | posted=${r.posted} | company=${r.company_code} | location_name=${r.location_name} | reason=${r.reason} | battery_used=${r.battery_used}%');
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

        // ✅ FIX #7 (OUT): pehle yeh timer SIRF hasBackup flag par chalta tha —
        // fast clock-out path yeh flag set hi nahi karta, is liye failed fast
        // clock-outs kabhi retry nahi hote the. Ab LEVEL-TRIGGERED: DB mein
        // unposted rows hain to sync attempt hota hai, flag ho ya na ho.
        final bool hasBackup = prefs.getBool(_keyHasBackup) ?? false;
        final unposted = await _repo.getUnposted();
        if (unposted.isEmpty && !hasBackup) return;

        if (await _isOnline()) {
          debugPrint('🔄 [OutVM] Periodic sync — ${unposted.length} unposted OUT record(s)');
          await _repo.syncUnposted();
          await fetchAllAttendanceOut();

          // ✅ FIX #5-spirit: backup keys sirf tab clear karo jab sab kuch
          // post ho chuka ho — pehle unconditionally clear hoti thin.
          if (hasBackup) {
            final remaining = await _repo.getUnposted();
            if (remaining.isEmpty) {
              await _clearBackupKeys(prefs);
              debugPrint('✅ [OutVM] Periodic sync complete — backup cleared');
            } else {
              debugPrint('⏸️ [OutVM] Periodic sync: ${remaining.length} still unposted — backup KEPT');
            }
          } else {
            debugPrint('✅ [OutVM] Periodic sync complete');
          }
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
      // ✅ FIX #5-spirit: backup keys sirf tab clear jab koi unposted OUT row
      // baqi na ho — warna failed POST ka safety-net ur jata tha.
      try {
        final remaining = await _repo.getUnposted();
        if (remaining.isEmpty) {
          await _clearBackupKeys(prefs);
          debugPrint('✅ [OutVM] Synced to server — backup cleared');
        } else {
          debugPrint('⏸️ [OutVM] ${remaining.length} OUT record(s) still unposted — backup KEPT');
        }
      } catch (_) {
        debugPrint('⚠️ [OutVM] post-sync check failed — backup KEPT (safe default)');
      }
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

    // ✅ FIX #4 (defensive): type-safe reads — poisoned String-typed keys par
    // getDouble() throw kar ke poora clockOut() fail kar deta tha.
    final saved = _safeReadDouble(prefs, _keyClockOutDistance);
    if (saved > 0) {
      debugPrint('📍 [OutVM] Using saved distance: ${saved.toStringAsFixed(3)} km');
      return saved;
    }

    final backup = _safeReadDouble(prefs, _keyBackupDistance);
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
    String? clockOutImage,
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
      if (clockOutImage != null) 'backup_clock_out_image': clockOutImage,
    };
    await prefs.setString(_keyBackupData, jsonEncode(data));
    await prefs.setBool(_keyHasBackup, true);
    await prefs.setDouble(_keyBackupDistance, totalDistance);
    debugPrint('📱 [OutVM] Backup saved: ${totalDistance.toStringAsFixed(3)} km, location: $finalLocationName, reason: $reason');
    debugPrint('📸 [OutVM] Backup image: ${clockOutImage != null ? "✅ (${clockOutImage.length} chars)" : "❌ NULL (auto/no-selfie)"}');
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
    // ✅ FIX #3: prefs.getString() int-typed key (emp_id = setInt) par throw
    // karta tha aur catch '' return karta tha — 11:58 PM auto clock-out
    // emp_id = '' ke saath post hota tha (server par orphan/reject).
    // prefs.get() har type ko safely toString() kar deta hai.
    try {
      final dynamic raw = prefs.get(key);
      if (raw == null) return '';
      return raw.toString();
    } catch (_) {
      return '';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ✅ FIX #3 — PRIVATE: TYPE-SAFE emp_id READER
  // login_view_model emp_id ko setInt() se save karta hai; getString() us par
  // TypeError deta hai. prefs.get() int/String dono handle karta hai.
  // ─────────────────────────────────────────────────────────────────────────
  String _safeEmpIdFromPrefs(SharedPreferences prefs) {
    try {
      final dynamic raw = prefs.get('emp_id');
      if (raw == null) return '';
      return raw.toString();
    } catch (_) {
      return '';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ✅ FIX #4 — PRIVATE: TYPE-SAFE DOUBLE READER
  // Kotlin (LocationMonitorService.handleCriticalEvent) 'fastClockOutDistance'
  // ko raw String likhta tha; Flutter prefs.getDouble() us par cast-error
  // throw karta tha aur poora restoreFastDataOnStartup() abort ho jata tha —
  // native auto-clockouts kabhi post nahi hote the. Yeh reader har shape
  // (double / int / raw String / Flutter double-prefix String) handle karta
  // hai, is liye purane "poisoned" devices bhi bina reinstall ke recover
  // ho jate hain.
  // ─────────────────────────────────────────────────────────────────────────
  double _safeReadDouble(SharedPreferences prefs, String key) {
    const String flutterDoublePrefix = 'VGhpc0lzVGhlUHJlZml4Rm9yQURvdWJsZS4h';
    try {
      final dynamic raw = prefs.get(key);
      if (raw == null) return 0.0;
      if (raw is double) return raw;
      if (raw is int) return raw.toDouble();
      if (raw is String) {
        final String s = raw.startsWith(flutterDoublePrefix)
            ? raw.substring(flutterDoublePrefix.length)
            : raw;
        return double.tryParse(s.trim()) ?? 0.0;
      }
    } catch (e) {
      debugPrint('⚠️ [OutVM] _safeReadDouble($key) error: $e');
    }
    return 0.0;
  }
}