//
// import 'dart:async';
// import 'dart:convert';
// import 'dart:typed_data';
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../Database/db_helper.dart';
// import '../Models/attendance_Model.dart';
// import '../Models/attendanceOut_model.dart';
// import '../ViewModels/attendance_view_model.dart';
// import '../ViewModels/attendance_out_view_model.dart';
// import '../ViewModels/location_view_model.dart';
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Enum that drives the single unified clocking function.
// //   startTravel    → clock-OUT current work location + clock-IN travel record
// //   switchLocation → clock-OUT travel record         + clock-IN new work location
// // ─────────────────────────────────────────────────────────────────────────────
// enum _ClockAction { startTravel, switchLocation }
//
// class TravelViewModel extends GetxController {
//   // ── Dependencies ──────────────────────────────────────────────────────────
//   final AttendanceViewModel    _attendanceVM    = Get.find<AttendanceViewModel>();
//   final AttendanceOutViewModel _attendanceOutVM = Get.find<AttendanceOutViewModel>();
//   final LocationViewModel      _locationVM      = Get.find<LocationViewModel>();
//
//   // ── Observables ───────────────────────────────────────────────────────────
//   var isTravelMode            = false.obs;
//   var travelStartTime         = Rx<DateTime?>(null);
//   var travelId                = ''.obs;
//   var currentWorkId           = ''.obs;
//   var pendingLocationSwitch   = false.obs;
//   var selectedNewLocation     = Rx<Map<String, dynamic>?>(null);
//   var currentLocationName     = ''.obs;
//   var travelElapsedTime       = '00:00:00'.obs;
//   var travelDistance          = 0.0.obs;
//
//   /// Loading flags — UI binds these for spinners / disabled states
//   var isStartingTravel        = false.obs;
//   var isSwitchingLocation     = false.obs;
//
//   /// Radius guard — true when last action was blocked because user is outside
//   /// the assigned location's geofence radius.
//   var isOutsideRadius         = false.obs;
//
//   // ── Timers ────────────────────────────────────────────────────────────────
//   Timer? _travelTimer;
//   Timer? _distanceUpdateTimer;
//
//   // ── SharedPreferences keys (travel state) ────────────────────────────────
//   static const String _kTravelMode      = 'is_travel_mode';
//   static const String _kTravelStartTime = 'travel_start_time';
//   static const String _kTravelId        = 'travel_id';
//   static const String _kCurrentWorkId   = 'current_work_id';
//   static const String _kPendingSwitch   = 'pending_location_switch';
//   static const String _kSelectedLoc     = 'selected_new_location';
//   static const String _kLastLoc         = 'last_location_name';
//   static const String _kCurrentLoc      = 'current_location_name';
//   static const String _kTravelDist      = 'travel_distance';
//   static const String _kCurrentAddress  = 'current_location_address';
//
//   // ── SharedPreferences keys written on every clock-in so the paired ────────
//   // ── clock-out (AttendanceOutViewModel.clockOut) can find the record ID. ───
//   static const String _kClockInTime  = 'clockInTime';
//   static const String _kCurrentId    = 'currentAttendanceId';
//   static const String _kAttendanceId = 'attendanceId';
//   static const String _kAltId        = 'clockInAttendanceId';
//   static const String _kIsClockedIn  = 'isClockedIn';
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // LIFECYCLE
//   // ─────────────────────────────────────────────────────────────────────────
//
//   @override
//   void onInit() {
//     super.onInit();
//     _restoreTravelState();
//   }
//
//   @override
//   void onClose() {
//     _stopAllTimers();
//     super.onClose();
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – Get next serial number from shared counter
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<int> _getNextSerialNumber() async {
//     final prefs = await SharedPreferences.getInstance();
//     final currentSerial = prefs.getInt('attendanceSerialCounter') ?? 0;
//     final nextSerial = currentSerial + 1;
//     await prefs.setInt('attendanceSerialCounter', nextSerial);
//     debugPrint('🔢 [TravelVM] Next serial number: $nextSerial');
//     return nextSerial;
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE — Travel ID builder (uses shared counter from attendance)
//   // ─────────────────────────────────────────────────────────────────────────
//   // Future<String> _buildTravelId({required String empId}) async {
//   //   final now = DateTime.now();
//   //   final day = DateFormat('dd').format(now);
//   //   final month = DateFormat('MMM').format(now);
//   //   final serial = await _getNextSerialNumber();
//   //   final serialStr = serial.toString().padLeft(3, '0');
//   //   final emp = empId.padLeft(2, '0');
//   //   final id = 'ATD-EMP-$emp-$day-$month-$serialStr';
//   //   debugPrint('🆔 [TravelVM] Generated travel ID: $id');
//   //   return id;
//   // }
//
//   Future<String> _buildTravelId({required String empId}) async {
//     final now = DateTime.now();
//     final day = DateFormat('dd').format(now);
//     final month = DateFormat('MMM').format(now);
//
//     final serial = await _getNextSerialNumber();
//     final serialStr = serial.toString().padLeft(3, '0');
//     final emp = empId.padLeft(2, '0');
//
//     // Get company code
//     final String companyCode = DBHelper.getCompanyCode() ?? '';
//
//     String id;
//
//     if (companyCode.isNotEmpty) {
//       id = '$companyCode-ATD-EMP-$emp-$day-$month-$serialStr';
//     } else {
//       id = 'ATD-EMP-$emp-$day-$month-$serialStr';
//     }
//
//     debugPrint('🆔 [TravelVM] Generated travel ID: $id (company: $companyCode)');
//     return id;
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC API  (called from travel_session_card.dart)
//   // ─────────────────────────────────────────────────────────────────────────
//
//   /// Button: [Start Travel]
//   Future<void> startTravel({required String empId}) async {
//     if (!_attendanceVM.isClockedIn.value) {
//       _snack('Cannot Start Travel', 'You are not clocked in.', Colors.red);
//       return;
//     }
//     if (isTravelMode.value) {
//       _snack('Already Traveling', 'You are already in travel mode.', Colors.orange);
//       return;
//     }
//     if (isStartingTravel.value) return;
//
//     // ── Radius guard ──────────────────────────────────────────────────────────
//     final radiusCheck = await _checkInsideCurrentLocationRadius();
//     if (!radiusCheck.inside) {
//       isOutsideRadius.value = true;
//       _snack(
//         '📍 Not in Location Radius',
//         'You are ${radiusCheck.distanceMeters.toStringAsFixed(0)} m away. '
//             'Move within ${radiusCheck.radiusMeters.toStringAsFixed(0)} m of '
//             '${radiusCheck.locationName} to start travel.',
//         Colors.red,
//         dur: 4,
//       );
//       return;
//     }
//     isOutsideRadius.value = false;
//     // ─────────────────────────────────────────────────────────────────────────
//
//     isStartingTravel.value = true;
//     try {
//       await _performClockAction(action: _ClockAction.startTravel, empId: empId);
//     } catch (e) {
//       debugPrint('❌ [TravelVM] startTravel error: $e');
//       _snack('Error', 'Failed to start travel: $e', Colors.red);
//     } finally {
//       isStartingTravel.value = false;
//     }
//   }
//
//   /// Stores the destination the user chose from the location picker.
//   Future<void> selectNewLocation(Map<String, dynamic> locationData) async {
//     debugPrint('📍 [TravelVM] Destination selected: ${locationData['location_name']}');
//     final prefs = await SharedPreferences.getInstance();
//     selectedNewLocation.value = locationData;
//     await prefs.setString(_kSelectedLoc, jsonEncode(locationData));
//     await prefs.setBool(_kPendingSwitch, true);
//     pendingLocationSwitch.value = true;
//
//     // Save address so clock-out records can use the real address
//     final address = locationData['location_address'] as String? ??
//         locationData['location_name']    as String? ?? '';
//     await prefs.setString('selected_location_address', address);
//   }
//
//   /// Button: [Switch Location]
//   Future<void> completeLocationSwitch({
//     required String empId,
//     Uint8List? photoBytes,
//   }) async {
//     if (!isTravelMode.value || selectedNewLocation.value == null) {
//       debugPrint('⚠️ [TravelVM] completeLocationSwitch — conditions not met');
//       return;
//     }
//     if (isSwitchingLocation.value) return;
//
//     // ── Radius guard: must be inside the DESTINATION location's radius ───────
//     final loc       = selectedNewLocation.value!;
//     final destLat   = (loc['lat']    ?? 0.0).toDouble();
//     final destLng   = (loc['lng']    ?? 0.0).toDouble();
//     final destRadius= (loc['radius'] ?? 100).toDouble();
//     final destName  = loc['location_name'] as String? ?? 'destination';
//
//     final radiusCheck = await _checkInsideRadius(
//       targetLat   : destLat,
//       targetLng   : destLng,
//       radiusMeters: destRadius,
//       locationName: destName,
//     );
//
//     if (!radiusCheck.inside) {
//       isOutsideRadius.value = true;
//       _snack(
//         '📍 Not at Destination',
//         'You are ${radiusCheck.distanceMeters.toStringAsFixed(0)} m away. '
//             'Move within ${radiusCheck.radiusMeters.toStringAsFixed(0)} m of '
//             '$destName to switch location.',
//         Colors.red,
//         dur: 4,
//       );
//       return;
//     }
//     isOutsideRadius.value = false;
//     // ─────────────────────────────────────────────────────────────────────────
//
//     isSwitchingLocation.value = true;
//     try {
//       await _performClockAction(
//         action    : _ClockAction.switchLocation,
//         empId     : empId,
//         photoBytes: photoBytes,
//       );
//     } catch (e) {
//       debugPrint('❌ [TravelVM] completeLocationSwitch error: $e');
//       _snack('Error', 'Failed to switch location: $e', Colors.red);
//     } finally {
//       isSwitchingLocation.value = false;
//     }
//   }
//
//   /// Called by timer_card when employee manually clocks out during travel.
//   Future<void> handleManualClockOut({
//     required String empId,
//     DateTime? clockOutTime,
//   }) async {
//     debugPrint('🛑 [TravelVM] Manual clock-out during travel');
//     final outTime = clockOutTime ?? DateTime.now();
//     final prefs   = await SharedPreferences.getInstance();
//
//     // Get the real address of current location for the clock-out record
//     final address = prefs.getString(_kCurrentAddress) ??
//         prefs.getString('selected_location_address') ??
//         prefs.getString(_kCurrentLoc) ?? '';
//
//     if (isTravelMode.value &&
//         travelId.value.isNotEmpty &&
//         travelStartTime.value != null) {
//       final dur = outTime.difference(travelStartTime.value!);
//
//       await _attendanceOutVM.addAttendanceOut(AttendanceOutModel(
//         attendance_out_id  : travelId.value,   // same ID as clock-in, no increment
//         emp_id             : empId,
//         total_time         : _fmt(dur),
//         total_distance     : travelDistance.value.toString(),
//         lat_out            : _locationVM.globalLatitude1.value.toString(),
//         lng_out            : _locationVM.globalLongitude1.value.toString(),
//         address            : address,
//         reason             : 'travel_end_manual',
//         attendance_out_time: outTime,
//         attendance_out_date: outTime,
//         posted             : 0,
//       ));
//       unawaited(_attendanceOutVM.syncUnposted());
//     }
//
//     await _clearAllTravelState();
//   }
//
//   /// Emergency cancel — deletes the travel clock-in record.
//   Future<void> cancelTravel() async {
//     if (!isTravelMode.value) return;
//     debugPrint('🛑 [TravelVM] Travel cancelled');
//     if (travelId.value.isNotEmpty) {
//       await _attendanceVM.deleteAttendance(travelId.value);
//     }
//     await _clearAllTravelState();
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // ★  UNIFIED CLOCK ACTION  ★
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<void> _performClockAction({
//     required _ClockAction action,
//     required String       empId,
//     Uint8List?            photoBytes,
//   }) async {
//     final now     = DateTime.now();
//     final prefs   = await SharedPreferences.getInstance();
//     final empData = await _getEmployeeData();
//
//     debugPrint('🔄 [TravelVM] _performClockAction → ${action.name}');
//
//     switch (action) {
//
//     // ──────────────────────────────────────────────────────────────────────
//       case _ClockAction.startTravel:
//       // ──────────────────────────────────────────────────────────────────────
//
//       // Get current location name + address for the clock-out reason/address
//         final currentLocName = prefs.getString(_kCurrentLoc) ??
//             prefs.getString('selected_location_name') ??
//             'Current Location';
//
//         // ── CLOCK-OUT: previous work location ─────────────────────────────
//         final prevId = await _attendanceVM.getCurrentAttendanceId();
//         if (prevId != null && prevId.isNotEmpty) {
//           final distance = await _locationVM.getImmediateDistance();
//           // Keep reason under 50 chars (Oracle column limit)
//           // Format: "Office ended" — truncate name so total ≤ 50
//           // " ended" = 6 chars → location name budget = 44 chars
//           final _locLabel = currentLocName.length > 44
//               ? currentLocName.substring(0, 44)
//               : currentLocName;
//           await _attendanceOutVM.clockOut(
//             empId        : empId,
//             clockOutTime : now,
//             totalDistance: distance,
//             isAuto       : true,
//             reason       : '$_locLabel ended',
//           );
//           debugPrint('✅ [TravelVM] [startTravel] Previous location clocked OUT');
//         } else {
//           debugPrint('⚠️ [TravelVM] [startTravel] No active attendance — clock-out skipped');
//         }
//
//         // ── CLOCK-IN: travel record ────────────────────────────────────────
//         final newTravelId = await _buildTravelId(empId: empId);
//
//         // Check if ID already exists
//         bool idExists = await _attendanceVM.checkForDuplicate(newTravelId);
//         String finalTravelId = newTravelId;
//         int retryCount = 0;
//         const maxRetries = 5;
//
//         while (idExists && retryCount < maxRetries) {
//           debugPrint('⚠️ [TravelVM] Travel ID already exists: $newTravelId - regenerating');
//           finalTravelId = await _buildTravelId(empId: empId);
//           idExists = await _attendanceVM.checkForDuplicate(finalTravelId);
//           retryCount++;
//         }
//
//         if (idExists) {
//           debugPrint('❌ [TravelVM] Failed to generate unique travel ID after $maxRetries attempts');
//           throw Exception('Failed to generate unique travel ID');
//         }
//
//         // Get current GPS coordinates for travel start
//         final Position currentPos = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.high,
//         );
//         final lat = currentPos.latitude.toString();
//         final lng = currentPos.longitude.toString();
//
//         // Get address for travel start location
//         final travelAddress = 'Travelling from $currentLocName to next location';
//
//         debugPrint('📝 [TravelVM] Attempting to insert travel record: $finalTravelId');
//         debugPrint('   - lat: $lat, lng: $lng');
//         debugPrint('   - address: $travelAddress');
//
//         final bool insertSuccess = await _clockInRecord(
//           attendanceId: finalTravelId,
//           empId       : empId,
//           empName     : empData['empName'] ?? '',
//           job         : '',  // no job for travel records
//           city        : empData['city']    ?? '',
//           lat         : lat,
//           lng         : lng,
//           address     : travelAddress,
//           clockTime   : now,
//           photoBytes  : null,
//           prefs       : prefs,
//         );
//
//         if (!insertSuccess) {
//           throw Exception('Failed to insert travel record into database');
//         }
//
//         debugPrint('✅ [TravelVM] [startTravel] Travel record clocked IN: $finalTravelId');
//
//         // ── Update observable + persist travel-mode flags ──────────────────
//         isTravelMode.value      = true;
//         travelStartTime.value   = now;
//         travelId.value          = finalTravelId;
//         travelDistance.value    = 0.0;
//         travelElapsedTime.value = '00:00:00';
//         _startTravelTracking();
//
//         await prefs.setBool(_kTravelMode,        true);
//         await prefs.setString(_kTravelStartTime, now.toIso8601String());
//         await prefs.setString(_kTravelId,        finalTravelId);
//         await prefs.setDouble(_kTravelDist,      0.0);
//         await prefs.setBool(_kPendingSwitch,     false);
//
//         unawaited(_attendanceVM.syncUnposted());
//         unawaited(_attendanceOutVM.syncUnposted());
//
//         _snack('🚗 Travel Started',
//             'Travel Started from $currentLocName',
//             Colors.orange,
//             dur: 3);
//         break;
//
//     // ──────────────────────────────────────────────────────────────────────
//       case _ClockAction.switchLocation:
//       // ──────────────────────────────────────────────────────────────────────
//
//         final locData         = selectedNewLocation.value!;
//         final newLocationName = locData['location_name']    as String? ?? 'Unknown';
//         final newLat          = (locData['lat']    ?? 0.0).toDouble();
//         final newLng          = (locData['lng']    ?? 0.0).toDouble();
//         final newRadius       = (locData['radius'] ?? 100).toDouble();
//         // Use the real address from the API response
//         final newAddress      = locData['location_address'] as String? ??
//             locData['location_name']    as String? ?? newLocationName;
//
//         // ── CLOCK-OUT: travel record (same ID as clock-in, no increment) ──
//         if (travelId.value.isNotEmpty && travelStartTime.value != null) {
//           final dur = now.difference(travelStartTime.value!);
//
//           // Keep reason under 50 chars (Oracle column limit)
//           final _shortName   = newLocationName.length > 28
//               ? newLocationName.substring(0, 28)
//               : newLocationName;
//           final _switchReason = 'switched_to_$_shortName'; // max 40 chars
//
//           await _attendanceOutVM.addAttendanceOut(AttendanceOutModel(
//             attendance_out_id  : travelId.value,  // same ID as travel clock-in
//             emp_id             : empId,
//             total_time         : _fmt(dur),
//             total_distance     : travelDistance.value.toString(),
//             lat_out            : newLat.toString(),
//             lng_out            : newLng.toString(),
//             address            : newAddress,       // real address of destination
//             reason             : _switchReason,
//             attendance_out_time: now,
//             attendance_out_date: now,
//             posted             : 0,
//           ));
//           debugPrint('✅ [TravelVM] [switchLocation] Travel clocked OUT');
//         }
//
//         // ── CLOCK-IN: new work location ────────────────────────────────────
//         final newWorkId = await _attendanceVM.generateAttendanceId(empId);
//
//         await _clockInRecord(
//           attendanceId: newWorkId,
//           empId       : empId,
//           empName     : empData['empName'] ?? '',
//           job         : empData['job']     ?? '',
//           city        : empData['city']    ?? '',
//           lat         : newLat.toString(),
//           lng         : newLng.toString(),
//           address     : newAddress,  // real address of new location
//           clockTime   : now,
//           photoBytes  : photoBytes,
//           prefs       : prefs,
//         );
//         debugPrint('✅ [TravelVM] [switchLocation] New location clocked IN: $newWorkId');
//
//         // ── Save location metadata ─────────────────────────────────────────
//         await prefs.setString(_kLastLoc,                  newLocationName);
//         await prefs.setString(_kCurrentLoc,               newLocationName);
//         await prefs.setString(_kCurrentAddress,           newAddress);
//         await prefs.setString('selected_location_address', newAddress);
//         await prefs.setDouble('selected_lat',             newLat);
//         await prefs.setDouble('selected_lng',             newLng);
//         await prefs.setDouble('selected_radius',          newRadius);
//         await prefs.setString('selected_location_name',   newLocationName);
//         await prefs.setString('${newWorkId}_location',    newLocationName);
//         await prefs.setDouble('${newWorkId}_lat',         newLat);
//         await prefs.setDouble('${newWorkId}_lng',         newLng);
//         currentLocationName.value = newLocationName;
//
//         // ── Exit travel mode ───────────────────────────────────────────────
//         isTravelMode.value          = false;
//         currentWorkId.value         = newWorkId;
//         travelId.value              = '';
//         travelStartTime.value       = null;
//         selectedNewLocation.value   = null;
//         pendingLocationSwitch.value = false;
//         _stopTravelTracking();
//         travelElapsedTime.value = '00:00:00';
//         travelDistance.value    = 0.0;
//
//         // ── Clear persisted travel state ───────────────────────────────────
//         await prefs.setBool(_kTravelMode,      false);
//         await prefs.setString(_kCurrentWorkId, newWorkId);
//         await prefs.remove(_kTravelId);
//         await prefs.remove(_kTravelStartTime);
//         await prefs.remove(_kPendingSwitch);
//         await prefs.remove(_kSelectedLoc);
//         await prefs.remove(_kTravelDist);
//
//         unawaited(_attendanceVM.syncUnposted());
//         unawaited(_attendanceOutVM.syncUnposted());
//
//         _snack('📍 Location Switched',
//             'New Location $newLocationName',
//             Colors.green,
//             dur: 3);
//         break;
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE — Shared clock-in helper (returns success/failure)
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<bool> _clockInRecord({
//     required String            attendanceId,
//     required String            empId,
//     required String            empName,
//     required String            job,
//     required String            city,
//     required String            lat,
//     required String            lng,
//     required String            address,
//     required DateTime          clockTime,
//     required SharedPreferences prefs,
//     Uint8List?                 photoBytes,
//   }) async {
//     try {
//       debugPrint('📝 [TravelVM] _clockInRecord - ID: $attendanceId');
//       debugPrint('   - lat: $lat, lng: $lng');
//       debugPrint('   - address: $address');
//       debugPrint('   - clockTime: $clockTime');
//
//       // 1. Write all prefs keys that AttendanceOutViewModel.clockOut() reads
//       await prefs.setString(_kClockInTime,  clockTime.toIso8601String());
//       await prefs.setString(_kCurrentId,    attendanceId);
//       await prefs.setString(_kAttendanceId, attendanceId);
//       await prefs.setString(_kAltId,        attendanceId);
//       await prefs.setBool(_kIsClockedIn,    true);
//
//       // 2. Mirror into AttendanceViewModel observable so UI reacts immediately
//       _attendanceVM.isClockedIn.value = true;
//
//       // 3. Encode photo if provided
//       final String? profile = (photoBytes != null && photoBytes.isNotEmpty)
//           ? base64Encode(photoBytes)
//           : null;
//
//       // 4. Insert DB record
//       final model = AttendanceModel(
//         attendance_in_id  : attendanceId,
//         emp_id            : empId,
//         emp_name          : empName,
//         job               : job,
//         lat_in            : lat,
//         lng_in            : lng,
//         city              : city,
//         address           : address,
//         attendance_in_date: clockTime,
//         attendance_in_time: clockTime,
//         profile           : profile,
//         posted            : 0,
//       );
//
//       await _attendanceVM.addAttendance(model);
//       debugPrint('✅ [TravelVM] _clockInRecord - Successfully inserted: $attendanceId');
//       return true;
//     } catch (e) {
//       debugPrint('❌ [TravelVM] _clockInRecord - Failed to insert: $e');
//       debugPrint('   Stack trace: ${StackTrace.current}');
//       return false;
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE — Restore travel state after app restart
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<void> _restoreTravelState() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       isTravelMode.value = prefs.getBool(_kTravelMode) ?? false;
//
//       final tStr = prefs.getString(_kTravelStartTime);
//       if (tStr != null) {
//         travelStartTime.value = DateTime.parse(tStr);
//         if (isTravelMode.value) _startTravelTracking();
//       }
//
//       travelId.value              = prefs.getString(_kTravelId)      ?? '';
//       currentWorkId.value         = prefs.getString(_kCurrentWorkId) ?? '';
//       currentLocationName.value   = prefs.getString(_kCurrentLoc)    ?? '';
//       pendingLocationSwitch.value = prefs.getBool(_kPendingSwitch)   ?? false;
//       travelDistance.value        = prefs.getDouble(_kTravelDist)    ?? 0.0;
//
//       final locStr = prefs.getString(_kSelectedLoc);
//       if (locStr != null) {
//         try {
//           selectedNewLocation.value = jsonDecode(locStr) as Map<String, dynamic>;
//         } catch (_) {}
//       }
//     } catch (e) {
//       debugPrint('❌ [TravelVM] _restoreTravelState: $e');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE — Travel tracking (elapsed timer + distance polling)
//   // ─────────────────────────────────────────────────────────────────────────
//   void _startTravelTracking() {
//     _stopAllTimers();
//     if (travelStartTime.value == null) return;
//
//     _travelTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//       if (travelStartTime.value != null) {
//         travelElapsedTime.value =
//             _fmt(DateTime.now().difference(travelStartTime.value!));
//       }
//     });
//
//     _distanceUpdateTimer =
//         Timer.periodic(const Duration(seconds: 10), (_) => _pollDistance());
//     _pollDistance();
//   }
//
//   Future<void> _pollDistance() async {
//     try {
//       final d = await _locationVM.getImmediateDistance();
//       if (d > 0) {
//         travelDistance.value = d;
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setDouble(_kTravelDist, d);
//       }
//     } catch (_) {}
//   }
//
//   void _stopTravelTracking() => _stopAllTimers();
//
//   void _stopAllTimers() {
//     _travelTimer?.cancel();
//     _distanceUpdateTimer?.cancel();
//     _travelTimer = null;
//     _distanceUpdateTimer = null;
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE — Clear all travel state
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<void> _clearAllTravelState() async {
//     isTravelMode.value          = false;
//     travelId.value              = '';
//     travelStartTime.value       = null;
//     selectedNewLocation.value   = null;
//     pendingLocationSwitch.value = false;
//     currentLocationName.value   = '';
//     _stopTravelTracking();
//     travelElapsedTime.value = '00:00:00';
//     travelDistance.value    = 0.0;
//
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_kTravelMode);
//     await prefs.remove(_kTravelId);
//     await prefs.remove(_kTravelStartTime);
//     await prefs.remove(_kPendingSwitch);
//     await prefs.remove(_kSelectedLoc);
//     await prefs.remove(_kCurrentLoc);
//     await prefs.remove(_kCurrentAddress);
//     await prefs.remove(_kTravelDist);
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE — Helpers
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<Map<String, String>> _getEmployeeData() async {
//     final prefs = await SharedPreferences.getInstance();
//     return {
//       'empId'  : _sp(prefs, 'emp_id'),
//       'empName': _spFB(prefs, ['emp_name', 'empName', 'userName', 'employee_name', 'name']),
//       'job'    : _spFB(prefs, ['job', 'designation', 'role', 'position']),
//       'city'   : _spFB(prefs, ['city', 'emp_city', 'location']),
//     };
//   }
//
//   String _sp(SharedPreferences p, String k) =>
//       p.get(k)?.toString() ?? '';
//
//   String _spFB(SharedPreferences p, List<String> keys) {
//     for (final k in keys) {
//       final v = p.get(k)?.toString().trim() ?? '';
//       if (v.isNotEmpty) return v;
//     }
//     return '';
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE — Radius check helpers
//   // ─────────────────────────────────────────────────────────────────────────
//
//   /// Result object returned by radius checks.
//   static const double _defaultRadius = 100.0; // metres, used when none saved
//
//   /// Checks whether the device is inside the CURRENT assigned location's
//   /// radius (read from SharedPreferences — written on every switchLocation).
//   Future<_RadiusResult> _checkInsideCurrentLocationRadius() async {
//     final prefs = await SharedPreferences.getInstance();
//     final lat    = prefs.getDouble('selected_lat');
//     final lng    = prefs.getDouble('selected_lng');
//     final radius = prefs.getDouble('selected_radius') ?? _defaultRadius;
//     final name   = prefs.getString('selected_location_name') ??
//         prefs.getString(_kCurrentLoc) ?? 'your location';
//
//     // If no saved location coordinates, allow the action (first clock-in).
//     if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
//       debugPrint('📍 [TravelVM] No saved location coords — radius check skipped');
//       return _RadiusResult(
//           inside: true, distanceMeters: 0, radiusMeters: radius, locationName: name);
//     }
//
//     return _checkInsideRadius(
//       targetLat   : lat,
//       targetLng   : lng,
//       radiusMeters: radius,
//       locationName: name,
//     );
//   }
//
//   /// Generic radius check against any [targetLat]/[targetLng]/[radiusMeters].
//   Future<_RadiusResult> _checkInsideRadius({
//     required double targetLat,
//     required double targetLng,
//     required double radiusMeters,
//     required String locationName,
//   }) async {
//     try {
//       final pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//         timeLimit      : const Duration(seconds: 10),
//       );
//       final dist = Geolocator.distanceBetween(
//           pos.latitude, pos.longitude, targetLat, targetLng);
//
//       debugPrint('📍 [TravelVM] Radius check: ${dist.toStringAsFixed(1)} m '
//           '(allowed ${radiusMeters.toStringAsFixed(0)} m) for "$locationName"');
//
//       return _RadiusResult(
//         inside        : dist <= radiusMeters,
//         distanceMeters: dist,
//         radiusMeters  : radiusMeters,
//         locationName  : locationName,
//       );
//     } catch (e) {
//       debugPrint('⚠️ [TravelVM] _checkInsideRadius GPS error: $e — allowing action');
//       // If GPS fails, allow the action rather than permanently blocking.
//       return _RadiusResult(
//           inside: true, distanceMeters: 0, radiusMeters: radiusMeters,
//           locationName: locationName);
//     }
//   }
//
//   String _fmt(Duration d) {
//     String z(int n) => n.toString().padLeft(2, '0');
//     return '${z(d.inHours)}:${z(d.inMinutes.remainder(60))}:${z(d.inSeconds.remainder(60))}';
//   }
//
//   void _snack(String title, String msg, Color bg, {int dur = 2}) {
//     Get.snackbar(title, msg,
//         snackPosition   : SnackPosition.TOP,
//         backgroundColor : bg,
//         colorText       : Colors.white,
//         duration        : Duration(seconds: dur));
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC — Getters
//   // ─────────────────────────────────────────────────────────────────────────
//   bool get isInTravelMode     => isTravelMode.value;
//   bool get hasPendingLocation => pendingLocationSwitch.value;
//   Map<String, dynamic>? get pendingLocation => selectedNewLocation.value;
//
//   String getTravelStatus() {
//     if (!isTravelMode.value) return 'Not traveling';
//     return 'Traveling: ${travelElapsedTime.value} • ${travelDistance.value.toStringAsFixed(2)} km';
//   }
//
//   String getCurrentLocationName()   => currentLocationName.value;
//   double getCurrentTravelDistance() => travelDistance.value;
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Small value-object used by the radius check helpers above.
// // ─────────────────────────────────────────────────────────────────────────────
// class _RadiusResult {
//   final bool   inside;
//   final double distanceMeters;
//   final double radiusMeters;
//   final String locationName;
//
//   const _RadiusResult({
//     required this.inside,
//     required this.distanceMeters,
//     required this.radiusMeters,
//     required this.locationName,
//   });
// }


import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';  // ✅ ADDED for reverse geocoding
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Database/db_helper.dart';
import '../Models/attendance_Model.dart';
import '../Models/attendanceOut_model.dart';
import '../ViewModels/attendance_view_model.dart';
import '../ViewModels/attendance_out_view_model.dart';
import '../ViewModels/location_view_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enum that drives the single unified clocking function.
//   startTravel    → clock-OUT current work location + clock-IN travel record
//   switchLocation → clock-OUT travel record         + clock-IN new work location
// ─────────────────────────────────────────────────────────────────────────────
enum _ClockAction { startTravel, switchLocation }

class TravelViewModel extends GetxController {
  // ── Dependencies ──────────────────────────────────────────────────────────
  final AttendanceViewModel    _attendanceVM    = Get.find<AttendanceViewModel>();
  final AttendanceOutViewModel _attendanceOutVM = Get.find<AttendanceOutViewModel>();
  final LocationViewModel      _locationVM      = Get.find<LocationViewModel>();

  // ── Observables ───────────────────────────────────────────────────────────
  var isTravelMode            = false.obs;
  var travelStartTime         = Rx<DateTime?>(null);
  var travelId                = ''.obs;
  var currentWorkId           = ''.obs;
  var pendingLocationSwitch   = false.obs;
  var selectedNewLocation     = Rx<Map<String, dynamic>?>(null);
  var currentLocationName     = ''.obs;
  var travelElapsedTime       = '00:00:00'.obs;
  var travelDistance          = 0.0.obs;

  /// Loading flags — UI binds these for spinners / disabled states
  var isStartingTravel        = false.obs;
  var isSwitchingLocation     = false.obs;

  /// Radius guard — true when last action was blocked because user is outside
  /// the assigned location's geofence radius.
  var isOutsideRadius         = false.obs;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _travelTimer;
  Timer? _distanceUpdateTimer;

  // ── SharedPreferences keys (travel state) ────────────────────────────────
  static const String _kTravelMode      = 'is_travel_mode';
  static const String _kTravelStartTime = 'travel_start_time';
  static const String _kTravelId        = 'travel_id';
  static const String _kCurrentWorkId   = 'current_work_id';
  static const String _kPendingSwitch   = 'pending_location_switch';
  static const String _kSelectedLoc     = 'selected_new_location';
  static const String _kLastLoc         = 'last_location_name';
  static const String _kCurrentLoc      = 'current_location_name';
  static const String _kTravelDist      = 'travel_distance';
  static const String _kCurrentAddress  = 'current_location_address';

  // ── SharedPreferences keys written on every clock-in so the paired ────────
  // ── clock-out (AttendanceOutViewModel.clockOut) can find the record ID. ───
  static const String _kClockInTime  = 'clockInTime';
  static const String _kCurrentId    = 'currentAttendanceId';
  static const String _kAttendanceId = 'attendanceId';
  static const String _kAltId        = 'clockInAttendanceId';
  static const String _kIsClockedIn  = 'isClockedIn';

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _restoreTravelState();
  }

  @override
  void onClose() {
    _stopAllTimers();
    super.onClose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – Reverse Geocoding Helper
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
      debugPrint('❌ [TravelVM Geocoding] Error: $e');
      return '$lat, $lng';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – Get next serial number from shared counter
  // ─────────────────────────────────────────────────────────────────────────
  Future<int> _getNextSerialNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final currentSerial = prefs.getInt('attendanceSerialCounter') ?? 0;
    final nextSerial = currentSerial + 1;
    await prefs.setInt('attendanceSerialCounter', nextSerial);
    debugPrint('🔢 [TravelVM] Next serial number: $nextSerial');
    return nextSerial;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE — Travel ID builder (uses shared counter from attendance)
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> _buildTravelId({required String empId}) async {
    final now = DateTime.now();
    final day = DateFormat('dd').format(now);
    final month = DateFormat('MMM').format(now);

    final serial = await _getNextSerialNumber();
    final serialStr = serial.toString().padLeft(3, '0');
    final emp = empId.padLeft(2, '0');

    // Get company code
    final String companyCode = DBHelper.getCompanyCode() ?? '';

    String id;

    if (companyCode.isNotEmpty) {
      id = '$companyCode-ATD-EMP-$emp-$day-$month-$serialStr';
    } else {
      id = 'ATD-EMP-$emp-$day-$month-$serialStr';
    }

    debugPrint('🆔 [TravelVM] Generated travel ID: $id (company: $companyCode)');
    return id;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC API  (called from travel_session_card.dart)
  // ─────────────────────────────────────────────────────────────────────────

  /// Button: [Start Travel]
  Future<void> startTravel({required String empId}) async {
    if (!_attendanceVM.isClockedIn.value) {
      _snack('Cannot Start Travel', 'You are not clocked in.', Colors.red);
      return;
    }
    if (isTravelMode.value) {
      _snack('Already Traveling', 'You are already in travel mode.', Colors.orange);
      return;
    }
    if (isStartingTravel.value) return;

    // ── Radius guard ──────────────────────────────────────────────────────────
    final radiusCheck = await _checkInsideCurrentLocationRadius();
    if (!radiusCheck.inside) {
      isOutsideRadius.value = true;
      _snack(
        '📍 Not in Location Radius',
        'You are ${radiusCheck.distanceMeters.toStringAsFixed(0)} m away. '
            'Move within ${radiusCheck.radiusMeters.toStringAsFixed(0)} m of '
            '${radiusCheck.locationName} to start travel.',
        Colors.red,
        dur: 4,
      );
      return;
    }
    isOutsideRadius.value = false;
    // ─────────────────────────────────────────────────────────────────────────

    isStartingTravel.value = true;
    try {
      await _performClockAction(action: _ClockAction.startTravel, empId: empId);
    } catch (e) {
      debugPrint('❌ [TravelVM] startTravel error: $e');
      _snack('Error', 'Failed to start travel: $e', Colors.red);
    } finally {
      isStartingTravel.value = false;
    }
  }

  /// Stores the destination the user chose from the location picker.
  Future<void> selectNewLocation(Map<String, dynamic> locationData) async {
    debugPrint('📍 [TravelVM] Destination selected: ${locationData['location_name']}');
    final prefs = await SharedPreferences.getInstance();
    selectedNewLocation.value = locationData;
    await prefs.setString(_kSelectedLoc, jsonEncode(locationData));
    await prefs.setBool(_kPendingSwitch, true);
    pendingLocationSwitch.value = true;

    // Save address so clock-out records can use the real address
    final address = locationData['location_address'] as String? ??
        locationData['location_name']    as String? ?? '';
    await prefs.setString('selected_location_address', address);
  }

  /// Button: [Switch Location]
  Future<void> completeLocationSwitch({
    required String empId,
    Uint8List? photoBytes,
  }) async {
    if (!isTravelMode.value || selectedNewLocation.value == null) {
      debugPrint('⚠️ [TravelVM] completeLocationSwitch — conditions not met');
      return;
    }
    if (isSwitchingLocation.value) return;

    // ── Radius guard: must be inside the DESTINATION location's radius ───────
    final loc       = selectedNewLocation.value!;
    final destLat   = (loc['lat']    ?? 0.0).toDouble();
    final destLng   = (loc['lng']    ?? 0.0).toDouble();
    final destRadius= (loc['radius'] ?? 100).toDouble();
    final destName  = loc['location_name'] as String? ?? 'destination';

    final radiusCheck = await _checkInsideRadius(
      targetLat   : destLat,
      targetLng   : destLng,
      radiusMeters: destRadius,
      locationName: destName,
    );

    if (!radiusCheck.inside) {
      isOutsideRadius.value = true;
      _snack(
        '📍 Not at Destination',
        'You are ${radiusCheck.distanceMeters.toStringAsFixed(0)} m away. '
            'Move within ${radiusCheck.radiusMeters.toStringAsFixed(0)} m of '
            '$destName to switch location.',
        Colors.red,
        dur: 4,
      );
      return;
    }
    isOutsideRadius.value = false;
    // ─────────────────────────────────────────────────────────────────────────

    isSwitchingLocation.value = true;
    try {
      await _performClockAction(
        action    : _ClockAction.switchLocation,
        empId     : empId,
        photoBytes: photoBytes,
      );
    } catch (e) {
      debugPrint('❌ [TravelVM] completeLocationSwitch error: $e');
      _snack('Error', 'Failed to switch location: $e', Colors.red);
    } finally {
      isSwitchingLocation.value = false;
    }
  }

  /// Called by timer_card when employee manually clocks out during travel.
  Future<void> handleManualClockOut({
    required String empId,
    DateTime? clockOutTime,
  }) async {
    debugPrint('🛑 [TravelVM] Manual clock-out during travel');
    final outTime = clockOutTime ?? DateTime.now();
    final prefs   = await SharedPreferences.getInstance();

    // Get current GPS location for address
    double currentLat = _locationVM.globalLatitude1.value;
    double currentLng = _locationVM.globalLongitude1.value;
    String currentAddress = '';

    try {
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      ).timeout(const Duration(seconds: 7));
      currentLat = currentPosition.latitude;
      currentLng = currentPosition.longitude;
      currentAddress = await _getAddressFromLatLng(currentLat, currentLng);
      debugPrint('📍 [TravelVM] Manual clock-out address: $currentAddress');
    } catch (e) {
      debugPrint('⚠️ [TravelVM] Using cached location for manual clock-out: $e');
      currentAddress = prefs.getString(_kCurrentAddress) ??
          prefs.getString('selected_location_address') ??
          'Unknown location';
    }

    // Get current location name
    final String currentLocName = prefs.getString(_kCurrentLoc) ??
        prefs.getString('selected_location_name') ??
        'Unknown Location';

    if (isTravelMode.value &&
        travelId.value.isNotEmpty &&
        travelStartTime.value != null) {
      final dur = outTime.difference(travelStartTime.value!);

      await _attendanceOutVM.addAttendanceOut(AttendanceOutModel(
        attendance_out_id  : travelId.value,
        emp_id             : empId,
        total_time         : _fmt(dur),
        total_distance     : travelDistance.value.toString(),
        lat_out            : currentLat.toString(),
        lng_out            : currentLng.toString(),
        address            : currentAddress,           // ✅ Full address
        location_name      : currentLocName,           // ✅ Location name
        reason             : 'Manual Clock-Out',       // ✅ Manual Clock-Out reason
        attendance_out_time: outTime,
        attendance_out_date: outTime,
        posted             : 0,
      ));
      unawaited(_attendanceOutVM.syncUnposted());
    }

    await _clearAllTravelState();
  }

  /// Emergency cancel — deletes the travel clock-in record.
  Future<void> cancelTravel() async {
    if (!isTravelMode.value) return;
    debugPrint('🛑 [TravelVM] Travel cancelled');
    if (travelId.value.isNotEmpty) {
      await _attendanceVM.deleteAttendance(travelId.value);
    }
    await _clearAllTravelState();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ★  UNIFIED CLOCK ACTION  ★
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _performClockAction({
    required _ClockAction action,
    required String       empId,
    Uint8List?            photoBytes,
  }) async {
    final now     = DateTime.now();
    final prefs   = await SharedPreferences.getInstance();
    final empData = await _getEmployeeData();

    debugPrint('🔄 [TravelVM] _performClockAction → ${action.name}');

    switch (action) {

    // ──────────────────────────────────────────────────────────────────────
      case _ClockAction.startTravel:
      // ──────────────────────────────────────────────────────────────────────

      // Get current location name + address for the clock-out reason/address
        final currentLocName = prefs.getString(_kCurrentLoc) ??
            prefs.getString('selected_location_name') ??
            'Current Location';

        // Get current address for clock-out
        double currentLat = _locationVM.globalLatitude1.value;
        double currentLng = _locationVM.globalLongitude1.value;
        String currentAddress = '';

        try {
          final currentPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          ).timeout(const Duration(seconds: 7));
          currentLat = currentPosition.latitude;
          currentLng = currentPosition.longitude;
          currentAddress = await _getAddressFromLatLng(currentLat, currentLng);
        } catch (e) {
          debugPrint('⚠️ [TravelVM] Using cached location: $e');
          currentAddress = prefs.getString(_kCurrentAddress) ??
              prefs.getString('selected_location_address') ??
              'Unknown address';
        }

        // ── CLOCK-OUT: previous work location ─────────────────────────────
        final prevId = await _attendanceVM.getCurrentAttendanceId();
        if (prevId != null && prevId.isNotEmpty) {
          final distance = await _locationVM.getImmediateDistance();

          // ✅ Reason: "Travel Started"
          // ✅ Location Name: current location name
          // ✅ Address: current full address
          await _attendanceOutVM.clockOut(
            empId        : empId,
            clockOutTime : now,
            totalDistance: distance,
            isAuto       : true,
            reason       : 'Travel Started',  // ✅ Reason for start travel
            customLocationName: currentLocName,  // ✅ Pass location name
            customAddress: currentAddress,  // ✅ Pass address
          );
          debugPrint('✅ [TravelVM] [startTravel] Previous location clocked OUT with reason: "Travel Started"');
          debugPrint('   📍 Location: $currentLocName');
          debugPrint('   📍 Address: $currentAddress');
        } else {
          debugPrint('⚠️ [TravelVM] [startTravel] No active attendance — clock-out skipped');
        }

        // ── CLOCK-IN: travel record ────────────────────────────────────────
        final newTravelId = await _buildTravelId(empId: empId);

        // Check if ID already exists
        bool idExists = await _attendanceVM.checkForDuplicate(newTravelId);
        String finalTravelId = newTravelId;
        int retryCount = 0;
        const maxRetries = 5;

        while (idExists && retryCount < maxRetries) {
          debugPrint('⚠️ [TravelVM] Travel ID already exists: $newTravelId - regenerating');
          finalTravelId = await _buildTravelId(empId: empId);
          idExists = await _attendanceVM.checkForDuplicate(finalTravelId);
          retryCount++;
        }

        if (idExists) {
          debugPrint('❌ [TravelVM] Failed to generate unique travel ID after $maxRetries attempts');
          throw Exception('Failed to generate unique travel ID');
        }

        // Get current GPS coordinates for travel start
        final Position currentPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        final lat = currentPos.latitude.toString();
        final lng = currentPos.longitude.toString();

        // Get address for travel start location
        final travelAddress = await _getAddressFromLatLng(currentPos.latitude, currentPos.longitude);

        debugPrint('📝 [TravelVM] Attempting to insert travel record: $finalTravelId');
        debugPrint('   - lat: $lat, lng: $lng');
        debugPrint('   - address: $travelAddress');

        final bool insertSuccess = await _clockInRecord(
          attendanceId: finalTravelId,
          empId       : empId,
          empName     : empData['empName'] ?? '',
          job         : '',  // no job for travel records
          city        : empData['city']    ?? '',
          lat         : lat,
          lng         : lng,
          address     : travelAddress,
          clockTime   : now,
          photoBytes  : null,
          prefs       : prefs,
        );

        if (!insertSuccess) {
          throw Exception('Failed to insert travel record into database');
        }

        debugPrint('✅ [TravelVM] [startTravel] Travel record clocked IN: $finalTravelId');

        // ── Update observable + persist travel-mode flags ──────────────────
        isTravelMode.value      = true;
        travelStartTime.value   = now;
        travelId.value          = finalTravelId;
        travelDistance.value    = 0.0;
        travelElapsedTime.value = '00:00:00';
        _startTravelTracking();

        await prefs.setBool(_kTravelMode,        true);
        await prefs.setString(_kTravelStartTime, now.toIso8601String());
        await prefs.setString(_kTravelId,        finalTravelId);
        await prefs.setDouble(_kTravelDist,      0.0);
        await prefs.setBool(_kPendingSwitch,     false);

        unawaited(_attendanceVM.syncUnposted());
        unawaited(_attendanceOutVM.syncUnposted());

        _snack('🚗 Travel Started',
            'Travel Started from $currentLocName',
            Colors.orange,
            dur: 3);
        break;

    // ──────────────────────────────────────────────────────────────────────
      case _ClockAction.switchLocation:
      // ──────────────────────────────────────────────────────────────────────

        final locData         = selectedNewLocation.value!;
        final newLocationName = locData['location_name']    as String? ?? 'Unknown';
        final newLat          = (locData['lat']    ?? 0.0).toDouble();
        final newLng          = (locData['lng']    ?? 0.0).toDouble();
        final newRadius       = (locData['radius'] ?? 100).toDouble();
        // Use the real address from the API response
        final newAddress      = locData['location_address'] as String? ??
            locData['location_name']    as String? ?? newLocationName;

        // ── CLOCK-OUT: travel record (same ID as clock-in, no increment) ──
        if (travelId.value.isNotEmpty && travelStartTime.value != null) {
          final dur = now.difference(travelStartTime.value!);

          // ✅ Reason: "Switched to [New Location Name]"
          final _switchReason = 'Switched to $newLocationName';

          // Get current location for travel clock-out (where user switched from)
          double currentLat = _locationVM.globalLatitude1.value;
          double currentLng = _locationVM.globalLongitude1.value;
          String currentAddress = '';

          try {
            final currentPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 5),
            ).timeout(const Duration(seconds: 7));
            currentLat = currentPosition.latitude;
            currentLng = currentPosition.longitude;
            currentAddress = await _getAddressFromLatLng(currentLat, currentLng);
          } catch (e) {
            debugPrint('⚠️ [TravelVM] Using cached location for switch: $e');
            currentAddress = prefs.getString(_kCurrentAddress) ?? 'Unknown address';
          }

          await _attendanceOutVM.addAttendanceOut(AttendanceOutModel(
            attendance_out_id  : travelId.value,
            emp_id             : empId,
            total_time         : _fmt(dur),
            total_distance     : travelDistance.value.toString(),
            lat_out            : currentLat.toString(),
            lng_out            : currentLng.toString(),
            address            : currentAddress,              // ✅ Address where user switched from
            location_name      : prefs.getString(_kCurrentLoc) ?? 'Travel Mode',  // ✅ Location name
            reason             : _switchReason,              // ✅ "Switched to [New Location Name]"
            attendance_out_time: now,
            attendance_out_date: now,
            posted             : 0,
          ));
          debugPrint('✅ [TravelVM] [switchLocation] Travel clocked OUT with reason: "$_switchReason"');
        }

        // ── CLOCK-IN: new work location ────────────────────────────────────
        final newWorkId = await _attendanceVM.generateAttendanceId(empId);

        await _clockInRecord(
          attendanceId: newWorkId,
          empId       : empId,
          empName     : empData['empName'] ?? '',
          job         : empData['job']     ?? '',
          city        : empData['city']    ?? '',
          lat         : newLat.toString(),
          lng         : newLng.toString(),
          address     : newAddress,  // real address of new location
          clockTime   : now,
          photoBytes  : photoBytes,
          prefs       : prefs,
        );
        debugPrint('✅ [TravelVM] [switchLocation] New location clocked IN: $newWorkId');

        // ── Save location metadata ─────────────────────────────────────────
        await prefs.setString(_kLastLoc,                  newLocationName);
        await prefs.setString(_kCurrentLoc,               newLocationName);
        await prefs.setString(_kCurrentAddress,           newAddress);
        await prefs.setString('selected_location_address', newAddress);
        await prefs.setDouble('selected_lat',             newLat);
        await prefs.setDouble('selected_lng',             newLng);
        await prefs.setDouble('selected_radius',          newRadius);
        await prefs.setString('selected_location_name',   newLocationName);
        await prefs.setString('${newWorkId}_location',    newLocationName);
        await prefs.setDouble('${newWorkId}_lat',         newLat);
        await prefs.setDouble('${newWorkId}_lng',         newLng);
        currentLocationName.value = newLocationName;

        // ── Exit travel mode ───────────────────────────────────────────────
        isTravelMode.value          = false;
        currentWorkId.value         = newWorkId;
        travelId.value              = '';
        travelStartTime.value       = null;
        selectedNewLocation.value   = null;
        pendingLocationSwitch.value = false;
        _stopTravelTracking();
        travelElapsedTime.value = '00:00:00';
        travelDistance.value    = 0.0;

        // ── Clear persisted travel state ───────────────────────────────────
        await prefs.setBool(_kTravelMode,      false);
        await prefs.setString(_kCurrentWorkId, newWorkId);
        await prefs.remove(_kTravelId);
        await prefs.remove(_kTravelStartTime);
        await prefs.remove(_kPendingSwitch);
        await prefs.remove(_kSelectedLoc);
        await prefs.remove(_kTravelDist);

        unawaited(_attendanceVM.syncUnposted());
        unawaited(_attendanceOutVM.syncUnposted());

        _snack('📍 Location Switched',
            'Switched to $newLocationName',
            Colors.green,
            dur: 3);
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE — Shared clock-in helper (returns success/failure)
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> _clockInRecord({
    required String            attendanceId,
    required String            empId,
    required String            empName,
    required String            job,
    required String            city,
    required String            lat,
    required String            lng,
    required String            address,
    required DateTime          clockTime,
    required SharedPreferences prefs,
    Uint8List?                 photoBytes,
  }) async {
    try {
      debugPrint('📝 [TravelVM] _clockInRecord - ID: $attendanceId');
      debugPrint('   - lat: $lat, lng: $lng');
      debugPrint('   - address: $address');
      debugPrint('   - clockTime: $clockTime');

      // 1. Write all prefs keys that AttendanceOutViewModel.clockOut() reads
      await prefs.setString(_kClockInTime,  clockTime.toIso8601String());
      await prefs.setString(_kCurrentId,    attendanceId);
      await prefs.setString(_kAttendanceId, attendanceId);
      await prefs.setString(_kAltId,        attendanceId);
      await prefs.setBool(_kIsClockedIn,    true);

      // 2. Mirror into AttendanceViewModel observable so UI reacts immediately
      _attendanceVM.isClockedIn.value = true;

      // 3. Encode photo if provided
      final String? profile = (photoBytes != null && photoBytes.isNotEmpty)
          ? base64Encode(photoBytes)
          : null;

      // 4. Insert DB record
      final model = AttendanceModel(
        attendance_in_id  : attendanceId,
        emp_id            : empId,
        emp_name          : empName,
        job               : job,
        lat_in            : lat,
        lng_in            : lng,
        city              : city,
        address           : address,
        attendance_in_date: clockTime,
        attendance_in_time: clockTime,
        profile           : profile,
        posted            : 0,
      );

      await _attendanceVM.addAttendance(model);
      debugPrint('✅ [TravelVM] _clockInRecord - Successfully inserted: $attendanceId');
      return true;
    } catch (e) {
      debugPrint('❌ [TravelVM] _clockInRecord - Failed to insert: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE — Restore travel state after app restart
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _restoreTravelState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isTravelMode.value = prefs.getBool(_kTravelMode) ?? false;

      final tStr = prefs.getString(_kTravelStartTime);
      if (tStr != null) {
        travelStartTime.value = DateTime.parse(tStr);
        if (isTravelMode.value) _startTravelTracking();
      }

      travelId.value              = prefs.getString(_kTravelId)      ?? '';
      currentWorkId.value         = prefs.getString(_kCurrentWorkId) ?? '';
      currentLocationName.value   = prefs.getString(_kCurrentLoc)    ?? '';
      pendingLocationSwitch.value = prefs.getBool(_kPendingSwitch)   ?? false;
      travelDistance.value        = prefs.getDouble(_kTravelDist)    ?? 0.0;

      final locStr = prefs.getString(_kSelectedLoc);
      if (locStr != null) {
        try {
          selectedNewLocation.value = jsonDecode(locStr) as Map<String, dynamic>;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('❌ [TravelVM] _restoreTravelState: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE — Travel tracking (elapsed timer + distance polling)
  // ─────────────────────────────────────────────────────────────────────────
  void _startTravelTracking() {
    _stopAllTimers();
    if (travelStartTime.value == null) return;

    _travelTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (travelStartTime.value != null) {
        travelElapsedTime.value =
            _fmt(DateTime.now().difference(travelStartTime.value!));
      }
    });

    _distanceUpdateTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _pollDistance());
    _pollDistance();
  }

  Future<void> _pollDistance() async {
    try {
      final d = await _locationVM.getImmediateDistance();
      if (d > 0) {
        travelDistance.value = d;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_kTravelDist, d);
      }
    } catch (_) {}
  }

  void _stopTravelTracking() => _stopAllTimers();

  void _stopAllTimers() {
    _travelTimer?.cancel();
    _distanceUpdateTimer?.cancel();
    _travelTimer = null;
    _distanceUpdateTimer = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE — Clear all travel state
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _clearAllTravelState() async {
    isTravelMode.value          = false;
    travelId.value              = '';
    travelStartTime.value       = null;
    selectedNewLocation.value   = null;
    pendingLocationSwitch.value = false;
    currentLocationName.value   = '';
    _stopTravelTracking();
    travelElapsedTime.value = '00:00:00';
    travelDistance.value    = 0.0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTravelMode);
    await prefs.remove(_kTravelId);
    await prefs.remove(_kTravelStartTime);
    await prefs.remove(_kPendingSwitch);
    await prefs.remove(_kSelectedLoc);
    await prefs.remove(_kCurrentLoc);
    await prefs.remove(_kCurrentAddress);
    await prefs.remove(_kTravelDist);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE — Helpers
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, String>> _getEmployeeData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'empId'  : _sp(prefs, 'emp_id'),
      'empName': _spFB(prefs, ['emp_name', 'empName', 'userName', 'employee_name', 'name']),
      'job'    : _spFB(prefs, ['job', 'designation', 'role', 'position']),
      'city'   : _spFB(prefs, ['city', 'emp_city', 'location']),
    };
  }

  String _sp(SharedPreferences p, String k) =>
      p.get(k)?.toString() ?? '';

  String _spFB(SharedPreferences p, List<String> keys) {
    for (final k in keys) {
      final v = p.get(k)?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE — Radius check helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Result object returned by radius checks.
  static const double _defaultRadius = 100.0; // metres, used when none saved

  /// Checks whether the device is inside the CURRENT assigned location's
  /// radius (read from SharedPreferences — written on every switchLocation).
  Future<_RadiusResult> _checkInsideCurrentLocationRadius() async {
    final prefs = await SharedPreferences.getInstance();
    final lat    = prefs.getDouble('selected_lat');
    final lng    = prefs.getDouble('selected_lng');
    final radius = prefs.getDouble('selected_radius') ?? _defaultRadius;
    final name   = prefs.getString('selected_location_name') ??
        prefs.getString(_kCurrentLoc) ?? 'your location';

    // If no saved location coordinates, allow the action (first clock-in).
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
      debugPrint('📍 [TravelVM] No saved location coords — radius check skipped');
      return _RadiusResult(
          inside: true, distanceMeters: 0, radiusMeters: radius, locationName: name);
    }

    return _checkInsideRadius(
      targetLat   : lat,
      targetLng   : lng,
      radiusMeters: radius,
      locationName: name,
    );
  }

  /// Generic radius check against any [targetLat]/[targetLng]/[radiusMeters].
  Future<_RadiusResult> _checkInsideRadius({
    required double targetLat,
    required double targetLng,
    required double radiusMeters,
    required String locationName,
  }) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit      : const Duration(seconds: 10),
      );
      final dist = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, targetLat, targetLng);

      debugPrint('📍 [TravelVM] Radius check: ${dist.toStringAsFixed(1)} m '
          '(allowed ${radiusMeters.toStringAsFixed(0)} m) for "$locationName"');

      return _RadiusResult(
        inside        : dist <= radiusMeters,
        distanceMeters: dist,
        radiusMeters  : radiusMeters,
        locationName  : locationName,
      );
    } catch (e) {
      debugPrint('⚠️ [TravelVM] _checkInsideRadius GPS error: $e — allowing action');
      // If GPS fails, allow the action rather than permanently blocking.
      return _RadiusResult(
          inside: true, distanceMeters: 0, radiusMeters: radiusMeters,
          locationName: locationName);
    }
  }

  String _fmt(Duration d) {
    String z(int n) => n.toString().padLeft(2, '0');
    return '${z(d.inHours)}:${z(d.inMinutes.remainder(60))}:${z(d.inSeconds.remainder(60))}';
  }

  void _snack(String title, String msg, Color bg, {int dur = 2}) {
    Get.snackbar(title, msg,
        snackPosition   : SnackPosition.TOP,
        backgroundColor : bg,
        colorText       : Colors.white,
        duration        : Duration(seconds: dur));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC — Getters
  // ─────────────────────────────────────────────────────────────────────────
  bool get isInTravelMode     => isTravelMode.value;
  bool get hasPendingLocation => pendingLocationSwitch.value;
  Map<String, dynamic>? get pendingLocation => selectedNewLocation.value;

  String getTravelStatus() {
    if (!isTravelMode.value) return 'Not traveling';
    return 'Traveling: ${travelElapsedTime.value} • ${travelDistance.value.toStringAsFixed(2)} km';
  }

  String getCurrentLocationName()   => currentLocationName.value;
  double getCurrentTravelDistance() => travelDistance.value;
}

// ─────────────────────────────────────────────────────────────────────────────
// Small value-object used by the radius check helpers above.
// ─────────────────────────────────────────────────────────────────────────────
class _RadiusResult {
  final bool   inside;
  final double distanceMeters;
  final double radiusMeters;
  final String locationName;

  const _RadiusResult({
    required this.inside,
    required this.distanceMeters,
    required this.radiusMeters,
    required this.locationName,
  });
}