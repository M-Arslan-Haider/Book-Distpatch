// // lib/ViewModels/location_view_model.dart
// //
// // Keeps every method that timer_card.dart already calls:
// //   • consolidateDailyGPXData()
// //   • consolidateDailyGPXDataForDate(DateTime)
// //   • saveLocationFromConsolidatedFile()
// //   • saveLocationFromConsolidatedFileForDate(DateTime)
// //   • getImmediateDistance()
// //   • calculateShiftDistance(DateTime)
// //
// // NEW hooks (call from AttendanceViewModel / AttendanceOutViewModel):
// //   • onClockIn()   → starts GPX position stream
// //   • onClockOut()  → stops stream, saves DB record, triggers server sync
//
// import 'dart:async';
// import 'dart:io';
// import 'dart:typed_data';
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get/get.dart';
// import 'package:gpx/gpx.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:synchronized/synchronized.dart';
//
// import '../Models/location_model.dart';
// import '../Repositories/location_repository.dart';
//
// class LocationViewModel extends GetxController {
//   // ── Dependency ────────────────────────────────────────────────────────────
//   final LocationRepository _repo = LocationRepository();
//
//   // ── Observables – GPS ─────────────────────────────────────────────────────
//   var latitude         = 0.0.obs;
//   var longitude        = 0.0.obs;
//   var address          = ''.obs;
//   var globalLatitude1  = 0.0.obs;   // backward-compat alias
//   var globalLongitude1 = 0.0.obs;   // backward-compat alias
//   var shopAddress      = ''.obs;    // backward-compat alias
//
//   // ── Observables – state ───────────────────────────────────────────────────
//   var isClockedIn   = false.obs;
//   var secondsPassed = 0.obs;        // used by trac.dart
//   var totalDistance = 0.0.obs;      // km, live
//   var isLoading     = false.obs;
//   var lastSyncTime  = ''.obs;
//
//   // ── Observables – DB records ──────────────────────────────────────────────
//   var allLocations = <LocationModel>[].obs;
//
//   // ── Internal – GPX ───────────────────────────────────────────────────────
//   Gpx?     _gpx;
//   Trk?     _track;
//   Trkseg?  _segment;
//   File?    _gpxFile;
//   bool     _gpxInitialised = false;
//   Position? _lastTrackPoint;
//
//   // ── Internal – serial ID ──────────────────────────────────────────────────
//   int    _serialCounter = 1;
//   String _currentMonth  = DateFormat('MMM').format(DateTime.now());
//   String _currentEmpId  = '';
//
//   // ── Internal – concurrency / timers ──────────────────────────────────────
//   final Lock                    _fileLock          = Lock();
//   StreamSubscription<Position>? _posStream;
//   Timer?                        _writeDebounceTimer;
//   Timer?                        _forcedPointTimer;
//   bool                          _pendingWrite      = false;
//   static const Duration         _writeDebounce     = Duration(seconds: 1);
//
//   // ── Distance cache ────────────────────────────────────────────────────────
//   double?   _cachedDistance;
//   DateTime? _lastDistanceCalc;
//   static const Duration _distanceCacheValidity = Duration(seconds: 5);
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // LIFECYCLE
//   // ─────────────────────────────────────────────────────────────────────────
//
//   @override
//   void onInit() {
//     super.onInit();
//     fetchAll();
//     _initSerialCounter();
//     _autoSyncOnStart();
//     _restoreClockedInState();
//   }
//
//   @override
//   void onClose() {
//     _posStream?.cancel();
//     _writeDebounceTimer?.cancel();
//     _forcedPointTimer?.cancel();
//     super.onClose();
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – CLOCK-IN HOOK
//   // Call this from AttendanceViewModel right after saving the ATD record.
//   // emp_id must already be written to SharedPreferences before calling.
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> onClockIn() async {
//     final prefs = await SharedPreferences.getInstance();
//     final empId = _readPref(prefs, 'emp_id');
//
//     debugPrint('🟢 [LocVM] onClockIn → empId=$empId');
//
//     // Reset tracking state
//     totalDistance.value = 0.0;
//     secondsPassed.value = 0;
//     _lastTrackPoint     = null;
//     _gpxInitialised     = false;
//     _cachedDistance     = null;
//     isClockedIn.value   = true;
//
//     await _initGpxFile(empId: empId);
//     await saveCurrentLocation();
//     _startPositionStream();
//     _startForcedPointTimer();
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – CLOCK-OUT HOOK
//   // Call this from AttendanceOutViewModel after saving the ATD-OUT record.
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> onClockOut() async {
//     debugPrint('🔴 [LocVM] onClockOut → stopping GPX');
//
//     await _stopPositionStream();
//     _forcedPointTimer?.cancel();
//     if (_pendingWrite) await _performFileWrite();
//
//     final distance = _gpxInitialised && _gpxFile != null
//         ? await _calculateDistanceFromFile(_gpxFile!.path)
//         : 0.0;
//     totalDistance.value = distance;
//
//     if (_gpxInitialised) {
//       await _saveLocationRecord(distance: distance);
//     }
//
//     isClockedIn.value   = false;
//     secondsPassed.value = 0;
//     unawaited(_trySync());
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – LIVE LOCATION
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> saveCurrentLocation() async {
//     try {
//       final pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//         timeLimit: const Duration(seconds: 10),
//       );
//       _applyPosition(pos.latitude, pos.longitude);
//
//       final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
//       if (marks.isNotEmpty) {
//         final p   = marks.first;
//         final adr = '${p.thoroughfare ?? ''} ${p.subLocality ?? ''}, '
//             '${p.locality ?? ''} ${p.postalCode ?? ''}, ${p.country ?? ''}';
//         address.value    = adr.trim().isEmpty ? 'Not Verified' : adr;
//         shopAddress.value = address.value;
//       }
//     } catch (e) {
//       debugPrint('❌ [LocVM] saveCurrentLocation: $e');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – DISTANCE  (used by AttendanceOutViewModel & timer_card)
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<double> getImmediateDistance() async {
//     // Return cached value if still fresh
//     if (_cachedDistance != null &&
//         _lastDistanceCalc != null &&
//         DateTime.now().difference(_lastDistanceCalc!) < _distanceCacheValidity) {
//       return _cachedDistance!;
//     }
//
//     // Try live GPX file first
//     if (_gpxInitialised && _gpxFile != null) {
//       final d = await _fileLock
//           .synchronized(() => _calculateDistanceFromFile(_gpxFile!.path));
//       _cachedDistance   = d;
//       _lastDistanceCalc = DateTime.now();
//       return d;
//     }
//
//     // Fallback: find today's GPX file by convention
//     try {
//       final prefs   = await SharedPreferences.getInstance();
//       final empId   = _readPref(prefs, 'emp_id');
//       final date    = DateFormat('dd-MM-yyyy').format(DateTime.now());
//       final dir     = await getDownloadsDirectory();
//       final path    = '${dir!.path}/track_${empId}_$date.gpx';
//       final altPath = '${dir.path}/track_$date.gpx';
//
//       for (final p in [path, altPath]) {
//         if (await File(p).exists()) {
//           final d = await _fileLock
//               .synchronized(() => _calculateDistanceFromFile(p));
//           _cachedDistance   = d;
//           _lastDistanceCalc = DateTime.now();
//           return d;
//         }
//       }
//     } catch (e) {
//       debugPrint('❌ [LocVM] getImmediateDistance fallback: $e');
//     }
//
//     return totalDistance.value;
//   }
//
//   Future<double> calculateShiftDistance(DateTime shiftStart) async {
//     try {
//       String? filePath;
//
//       if (_gpxInitialised && _gpxFile != null) {
//         filePath = _gpxFile!.path;
//       } else {
//         final prefs = await SharedPreferences.getInstance();
//         final empId = _readPref(prefs, 'emp_id');
//         final date  = DateFormat('dd-MM-yyyy').format(DateTime.now());
//         final dir   = await getDownloadsDirectory();
//         filePath = '${dir!.path}/track_${empId}_$date.gpx';
//       }
//
//       if (!await File(filePath!).exists()) return 0.0;
//
//       final content = await _fileLock
//           .synchronized(() => File(filePath!).readAsString());
//       if (content.isEmpty) return 0.0;
//
//       final gpx    = GpxReader().fromString(content);
//       double total = 0.0;
//
//       for (final trk in gpx.trks) {
//         for (final seg in trk.trksegs) {
//           final pts = seg.trkpts
//               .where((p) => p.time != null && p.time!.isAfter(shiftStart))
//               .toList();
//           for (int i = 0; i < pts.length - 1; i++) {
//             total += _distBetween(pts[i], pts[i + 1]);
//           }
//         }
//       }
//       return total;
//     } catch (e) {
//       debugPrint('❌ [LocVM] calculateShiftDistance: $e');
//       return 0.0;
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – GPX CONSOLIDATION  (called by timer_card.dart)
//   // ─────────────────────────────────────────────────────────────────────────
//
//   /// Merge all segment GPX files for [date] into a single daily file.
//   Future<void> consolidateDailyGPXDataForDate(DateTime date) async {
//     try {
//       final dateStr = DateFormat('dd-MM-yyyy').format(date);
//       final prefs   = await SharedPreferences.getInstance();
//       final empId   = _readPref(prefs, 'emp_id');
//       final dir     = await getDownloadsDirectory();
//       final dailyPath = '${dir!.path}/track_${empId}_$dateStr.gpx';
//
//       debugPrint('🔄 [LocVM] Consolidating GPX for: $dateStr');
//
//       await _fileLock.synchronized(() async {
//         final dailyFile = File(dailyPath);
//
//         if (!await dailyFile.exists()) {
//           await dailyFile.writeAsString(_blankGpx(dateStr));
//         }
//
//         // Collect every other .gpx for this date
//         final segFiles = (await dir.list().toList())
//             .whereType<File>()
//             .where((f) =>
//         f.path.endsWith('.gpx') &&
//             f.path.contains(dateStr) &&
//             f.path != dailyPath)
//             .toList();
//
//         if (segFiles.isEmpty) {
//           debugPrint('📁 [LocVM] No segment files to merge');
//           return;
//         }
//
//         final dailyContent = await dailyFile.readAsString();
//         final dailyGpx     = GpxReader().fromString(dailyContent);
//
//         if (dailyGpx.trks.isEmpty) dailyGpx.trks.add(Trk());
//         if (dailyGpx.trks.first.trksegs.isEmpty) {
//           dailyGpx.trks.first.trksegs.add(Trkseg());
//         }
//
//         final mainSeg   = dailyGpx.trks.first.trksegs.first;
//         final existing  = <String>{};
//         for (final pt in mainSeg.trkpts) {
//           if (pt.lat != null && pt.lon != null && pt.time != null) {
//             existing.add(
//                 '${pt.lat}_${pt.lon}_${pt.time!.millisecondsSinceEpoch}');
//           }
//         }
//
//         int added = 0;
//         for (final segFile in segFiles) {
//           try {
//             final segContent = await segFile.readAsString();
//             final segGpx     = GpxReader().fromString(segContent);
//             for (final trk in segGpx.trks) {
//               for (final seg in trk.trksegs) {
//                 for (final pt in seg.trkpts) {
//                   if (pt.lat != null &&
//                       pt.lon != null &&
//                       pt.time != null) {
//                     final key =
//                         '${pt.lat}_${pt.lon}_${pt.time!.millisecondsSinceEpoch}';
//                     if (!existing.contains(key)) {
//                       mainSeg.trkpts.add(pt);
//                       existing.add(key);
//                       added++;
//                     }
//                   }
//                 }
//               }
//             }
//           } catch (e) {
//             debugPrint('⚠️ [LocVM] Merge error ${segFile.path}: $e');
//           }
//         }
//
//         // Sort by time
//         mainSeg.trkpts.sort((a, b) {
//           if (a.time == null || b.time == null) return 0;
//           return a.time!.compareTo(b.time!);
//         });
//
//         await dailyFile.writeAsString(
//             GpxWriter().asString(dailyGpx, pretty: true),
//             flush: true);
//
//         debugPrint('✅ [LocVM] Consolidated: +$added pts → $dailyPath');
//       });
//     } catch (e) {
//       debugPrint('❌ [LocVM] consolidateDailyGPXDataForDate: $e');
//     }
//   }
//
//   /// Convenience wrapper for today.
//   Future<void> consolidateDailyGPXData() =>
//       consolidateDailyGPXDataForDate(DateTime.now());
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – SAVE LOCATION FROM CONSOLIDATED FILE  (called by timer_card)
//   // ─────────────────────────────────────────────────────────────────────────
//
//   /// Read the consolidated daily GPX file for [date], calculate distance,
//   /// insert a LocationModel row into the DB, and attempt server sync.
//   Future<void> saveLocationFromConsolidatedFileForDate(DateTime date) async {
//     try {
//       final dateStr   = DateFormat('dd-MM-yyyy').format(date);
//       final prefs     = await SharedPreferences.getInstance();
//       final empId     = _readPref(prefs, 'emp_id');
//       final empName   = _readPref(prefs, 'emp_name',
//           fallbacks: ['empName', 'employee_name', 'name', 'userName']);
//       final dir       = await getDownloadsDirectory();
//       final filePath  = '${dir!.path}/track_${empId}_$dateStr.gpx';
//
//       debugPrint('💾 [LocVM] Saving from consolidated file: $filePath');
//
//       final file = File(filePath);
//       if (!await file.exists()) {
//         debugPrint('❌ [LocVM] File not found: $filePath');
//         return;
//       }
//
//       final bytes    = await _fileLock
//           .synchronized(() => file.readAsBytes());
//       final distance = await _calculateDistanceFromFile(filePath);
//
//       await _initSerialCounter();
//       final locationId = _buildLocationId(empId: empId);
//
//       final model = LocationModel(
//         locationId    : locationId,
//         locationDate  : DateFormat('yyyy-MM-dd').format(date),
//         locationTime  : DateFormat('HH:mm:ss').format(date),
//         fileName      : 'track_${empId}_$dateStr.gpx',
//         empId         : empId,
//         totalDistance : distance.toStringAsFixed(3),
//         empName       : empName,
//         posted        : 0,
//         body          : Uint8List.fromList(bytes),
//       );
//
//       await _repo.add(model);
//       await fetchAll();
//
//       _serialCounter++;
//       await _saveSerialCounter();
//
//       unawaited(_trySync());
//
//       debugPrint(
//           '✅ [LocVM] Saved $locationId | ${distance.toStringAsFixed(3)} km');
//     } catch (e) {
//       debugPrint('❌ [LocVM] saveLocationFromConsolidatedFileForDate: $e');
//     }
//   }
//
//   /// Convenience wrapper for today.
//   Future<void> saveLocationFromConsolidatedFile() =>
//       saveLocationFromConsolidatedFileForDate(DateTime.now());
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – DB OPERATIONS
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> fetchAll() async {
//     allLocations.value = await _repo.getAll();
//   }
//
//   Future<void> add(LocationModel model) async {
//     await _repo.add(model);
//     await fetchAll();
//   }
//
//   Future<void> delete(String id) async {
//     await _repo.delete(id);
//     await fetchAll();
//   }
//
//   Future<void> syncNow() async {
//     try {
//       isLoading.value = true;
//       await _repo.syncUnposted();
//       await fetchAll();
//       lastSyncTime.value = DateFormat('hh:mm a').format(DateTime.now());
//       Get.snackbar('Sync Complete', 'Location data synced',
//           backgroundColor: Colors.green, colorText: Colors.white);
//     } catch (e) {
//       debugPrint('❌ [LocVM] syncNow: $e');
//     } finally {
//       isLoading.value = false;
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – GPX FILE INIT
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> _initGpxFile({required String empId}) async {
//     try {
//       final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
//       final dir  = await getDownloadsDirectory();
//       final path = '${dir!.path}/track_${empId}_$date.gpx';
//
//       _gpxFile = File(path);
//       _gpx     = Gpx();
//       _track   = Trk()..name = 'Track $date';
//       _segment = Trkseg();
//       _track!.trksegs.add(_segment!);
//       _gpx!.trks.add(_track!);
//
//       if (await _gpxFile!.exists()) {
//         final content = await _gpxFile!.readAsString();
//         if (content.isNotEmpty) {
//           try {
//             _gpx    = GpxReader().fromString(content);
//             _track  = _gpx!.trks.isNotEmpty ? _gpx!.trks.first : _track;
//             _segment = _track!.trksegs.isNotEmpty
//                 ? _track!.trksegs.last
//                 : Trkseg().._also(() => _track!.trksegs.add(_segment!));
//             debugPrint(
//                 '📂 [LocVM] Loaded existing GPX (${_segment!.trkpts.length} pts)');
//           } catch (_) {
//             await _gpxFile!.writeAsString(_blankGpx(date), flush: true);
//           }
//         }
//       } else {
//         await _gpxFile!.writeAsString(_blankGpx(date), flush: true);
//       }
//
//       _gpxInitialised = true;
//       debugPrint('✅ [LocVM] GPX ready: $path');
//     } catch (e) {
//       debugPrint('❌ [LocVM] _initGpxFile: $e');
//     }
//   }
//
//   String _blankGpx(String date) => '''<?xml version="1.0" encoding="UTF-8"?>
// <gpx version="1.1" creator="GPS_Attendance">
//   <trk><n>Track $date</n><trkseg></trkseg></trk>
// </gpx>''';
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – POSITION STREAM
//   // ─────────────────────────────────────────────────────────────────────────
//
//   void _startPositionStream() {
//     _posStream?.cancel();
//
//     final settings = AndroidSettings(
//       accuracy        : LocationAccuracy.high,
//       distanceFilter  : 10,
//       intervalDuration: const Duration(seconds: 30),
//     );
//
//     _posStream = Geolocator.getPositionStream(locationSettings: settings)
//         .listen(_handlePosition, onError: (e) {
//       debugPrint('❌ [LocVM] Stream error: $e');
//     });
//     debugPrint('▶️ [LocVM] Position stream started');
//   }
//
//   Future<void> _stopPositionStream() async {
//     await _posStream?.cancel();
//     _posStream = null;
//     debugPrint('⏹ [LocVM] Position stream stopped');
//   }
//
//   void _handlePosition(Position pos) {
//     if (!_gpxInitialised || _segment == null) return;
//
//     _applyPosition(pos.latitude, pos.longitude);
//
//     final wpt = Wpt(
//       lat : pos.latitude,
//       lon : pos.longitude,
//       time: pos.timestamp ?? DateTime.now(),
//       ele : pos.altitude,
//     );
//     _segment!.trkpts.add(wpt);
//     _lastTrackPoint = pos;
//
//     if (_segment!.trkpts.length >= 2) {
//       final prev = _segment!.trkpts[_segment!.trkpts.length - 2];
//       totalDistance.value += _distBetween(prev, wpt);
//       _cachedDistance      = null;
//     }
//
//     _debouncedWrite();
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – FORCED POINT TIMER
//   // ─────────────────────────────────────────────────────────────────────────
//
//   void _startForcedPointTimer() {
//     _forcedPointTimer?.cancel();
//     _forcedPointTimer = Timer.periodic(
//       const Duration(seconds: 60),
//           (_) async {
//         if (!_gpxInitialised || _lastTrackPoint == null || _segment == null) {
//           return;
//         }
//         _segment!.trkpts.add(Wpt(
//           lat : _lastTrackPoint!.latitude,
//           lon : _lastTrackPoint!.longitude,
//           time: DateTime.now(),
//           name: 'heartbeat',
//         ));
//         _debouncedWrite();
//       },
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – FILE WRITE
//   // ─────────────────────────────────────────────────────────────────────────
//
//   void _debouncedWrite() {
//     _pendingWrite = true;
//     _writeDebounceTimer?.cancel();
//     _writeDebounceTimer = Timer(_writeDebounce, _performFileWrite);
//   }
//
//   Future<void> _performFileWrite() async {
//     if (!_pendingWrite || !_gpxInitialised || _gpxFile == null || _gpx == null) {
//       return;
//     }
//     await _fileLock.synchronized(() async {
//       try {
//         await _gpxFile!.writeAsString(
//             GpxWriter().asString(_gpx!, pretty: true),
//             flush: true);
//         _pendingWrite = false;
//         debugPrint(
//             '💾 [LocVM] GPX written – ${_segment?.trkpts.length ?? 0} pts');
//       } catch (e) {
//         debugPrint('❌ [LocVM] File write: $e');
//       }
//     });
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – SAVE LOCATION RECORD TO DB  (used by onClockOut)
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> _saveLocationRecord({required double distance}) async {
//     try {
//       final prefs       = await SharedPreferences.getInstance();
//       final empId       = _readPref(prefs, 'emp_id');
//       final empName     = _readPref(prefs, 'emp_name',
//           fallbacks: ['empName', 'employee_name', 'name', 'userName']);
//       final now         = DateTime.now();
//       final dateStr     = DateFormat('yyyy-MM-dd').format(now);
//       final timeStr     = DateFormat('HH:mm:ss').format(now);
//       final fileDateStr = DateFormat('dd-MM-yyyy').format(now);
//
//       await _initSerialCounter();
//       final locationId = _buildLocationId(empId: empId);
//
//       final bytes = (_gpxFile != null && _gpxFile!.existsSync())
//           ? Uint8List.fromList(await _gpxFile!.readAsBytes())
//           : null;
//
//       final model = LocationModel(
//         locationId    : locationId,
//         locationDate  : dateStr,
//         locationTime  : timeStr,
//         fileName      : 'track_${empId}_$fileDateStr.gpx',
//         empId         : empId,
//         totalDistance : distance.toStringAsFixed(3),
//         empName       : empName,
//         posted        : 0,
//         body          : bytes,
//       );
//
//       await _repo.add(model);
//       await fetchAll();
//
//       _serialCounter++;
//       await _saveSerialCounter();
//
//       debugPrint(
//           '✅ [LocVM] DB record saved: $locationId | ${distance.toStringAsFixed(3)} km');
//     } catch (e) {
//       debugPrint('❌ [LocVM] _saveLocationRecord: $e');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – SERIAL COUNTER
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> _initSerialCounter() async {
//     final prefs    = await SharedPreferences.getInstance();
//     _serialCounter = prefs.getInt('locationSerialCounter') ?? 1;
//     _currentMonth  = prefs.getString('locationCurrentMonth')
//         ?? DateFormat('MMM').format(DateTime.now());
//     _currentEmpId  = _readPref(prefs, 'emp_id');
//   }
//
//   Future<void> _saveSerialCounter() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setInt('locationSerialCounter', _serialCounter);
//     await prefs.setString('locationCurrentMonth', _currentMonth);
//   }
//
//   String _buildLocationId({required String empId}) {
//     final now   = DateTime.now();
//     final day   = DateFormat('dd').format(now);
//     final month = DateFormat('MMM').format(now);
//
//     if (_currentMonth != month) { _serialCounter = 1; _currentMonth = month; }
//     if (_currentEmpId != empId) { _serialCounter = 1; _currentEmpId = empId; }
//
//     final serial  = _serialCounter.toString().padLeft(3, '0');
//     final empPart = empId.padLeft(2, '0');
//     final id      = 'LOC-EMP-$empPart-$day-$month-$serial';
//     debugPrint('🆔 [LocVM] ID: $id');
//     return id;
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – DISTANCE
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<double> _calculateDistanceFromFile(String path) async {
//     try {
//       final file = File(path);
//       if (!await file.exists()) return 0.0;
//
//       final content = await file.readAsString();
//       if (content.isEmpty) return 0.0;
//
//       final gpx    = GpxReader().fromString(content);
//       double total = 0.0;
//
//       for (final trk in gpx.trks) {
//         for (final seg in trk.trksegs) {
//           final pts = seg.trkpts;
//           for (int i = 0; i < pts.length - 1; i++) {
//             total += _distBetween(pts[i], pts[i + 1]);
//           }
//         }
//       }
//       return total;
//     } catch (e) {
//       debugPrint('⚠️ [LocVM] _calculateDistanceFromFile: $e');
//       return 0.0;
//     }
//   }
//
//   double _distBetween(Wpt a, Wpt b) {
//     if (a.lat == null || a.lon == null || b.lat == null || b.lon == null) {
//       return 0.0;
//     }
//     return Geolocator.distanceBetween(
//       a.lat!.toDouble(), a.lon!.toDouble(),
//       b.lat!.toDouble(), b.lon!.toDouble(),
//     ) /
//         1000.0;
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – RESTORE STATE ON RESTART
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> _restoreClockedInState() async {
//     final prefs        = await SharedPreferences.getInstance();
//     final wasClockedIn = prefs.getBool('isClockedIn') ?? false;
//     if (!wasClockedIn) return;
//
//     debugPrint('🔄 [LocVM] Restoring GPS state…');
//     final empId = _readPref(prefs, 'emp_id');
//     isClockedIn.value = true;
//     await _initGpxFile(empId: empId);
//     _startPositionStream();
//     _startForcedPointTimer();
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – SYNC / CONNECTIVITY
//   // ─────────────────────────────────────────────────────────────────────────
//
//   void _autoSyncOnStart() {
//     Future.delayed(const Duration(seconds: 3), () async {
//       if (await _isOnline()) {
//         await _repo.syncUnposted();
//         await fetchAll();
//       }
//     });
//   }
//
//   Future<void> _trySync() async {
//     if (await _isOnline()) {
//       await _repo.syncUnposted();
//       await fetchAll();
//     }
//   }
//
//   Future<bool> _isOnline() async {
//     try {
//       final res = await http
//           .head(Uri.parse('https://www.google.com'))
//           .timeout(const Duration(seconds: 3));
//       return res.statusCode == 200;
//     } catch (_) {
//       return false;
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – HELPERS
//   // ─────────────────────────────────────────────────────────────────────────
//
//   void _applyPosition(double lat, double lng) {
//     latitude.value         = lat;
//     longitude.value        = lng;
//     globalLatitude1.value  = lat;
//     globalLongitude1.value = lng;
//   }
//
//   String _readPref(
//       SharedPreferences prefs,
//       String key, {
//         List<String> fallbacks = const [],
//       }) {
//     for (final k in [key, ...fallbacks]) {
//       try {
//         final raw = prefs.get(k);
//         if (raw != null) {
//           final val = raw.toString().trim();
//           if (val.isNotEmpty) return val;
//         }
//       } catch (_) {}
//     }
//     return '';
//   }
// }
//
// // ignore: unused_element
// extension _Also on Object {
//   void _also(void Function() block) => block();
// }

// lib/ViewModels/location_view_model.dart
//
// Keeps every method that timer_card.dart already calls:
//   • consolidateDailyGPXData()
//   • consolidateDailyGPXDataForDate(DateTime)
//   • saveLocationFromConsolidatedFile()
//   • saveLocationFromConsolidatedFileForDate(DateTime)
//   • getImmediateDistance()
//   • calculateShiftDistance(DateTime)
//
// NEW hooks (call from AttendanceViewModel / AttendanceOutViewModel):
//   • onClockIn()   → starts GPX position stream
//   • onClockOut()  → stops stream, saves DB record, triggers server sync

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:gpx/gpx.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import '../Models/location_model.dart';
import '../Repositories/location_repository.dart';

class LocationViewModel extends GetxController {
  // ── Dependency ────────────────────────────────────────────────────────────
  final LocationRepository _repo = LocationRepository();

  // ── Observables – GPS ─────────────────────────────────────────────────────
  var latitude         = 0.0.obs;
  var longitude        = 0.0.obs;
  var address          = ''.obs;
  var globalLatitude1  = 0.0.obs;   // backward-compat alias
  var globalLongitude1 = 0.0.obs;   // backward-compat alias
  var shopAddress      = ''.obs;    // backward-compat alias

  // ── Observables – state ───────────────────────────────────────────────────
  var isClockedIn   = false.obs;
  var secondsPassed = 0.obs;        // used by trac.dart
  var totalDistance = 0.0.obs;      // km, live
  var isLoading     = false.obs;
  var lastSyncTime  = ''.obs;

  // ── Observables – DB records ──────────────────────────────────────────────
  var allLocations = <LocationModel>[].obs;

  // ── Internal – GPX ───────────────────────────────────────────────────────
  Gpx?     _gpx;
  Trk?     _track;
  Trkseg?  _segment;
  File?    _gpxFile;
  bool     _gpxInitialised = false;
  Position? _lastTrackPoint;

  // ── Internal – serial ID ──────────────────────────────────────────────────
  int    _serialCounter = 1;
  String _currentMonth  = DateFormat('MMM').format(DateTime.now());
  String _currentEmpId  = '';

  // ── Internal – concurrency / timers ──────────────────────────────────────
  final Lock                    _fileLock          = Lock();
  StreamSubscription<Position>? _posStream;
  Timer?                        _writeDebounceTimer;
  Timer?                        _forcedPointTimer;
  bool                          _pendingWrite      = false;
  static const Duration         _writeDebounce     = Duration(seconds: 1);

  // ── Distance cache ────────────────────────────────────────────────────────
  double?   _cachedDistance;
  DateTime? _lastDistanceCalc;
  static const Duration _distanceCacheValidity = Duration(seconds: 5);

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    fetchAll();
    _initSerialCounter();
    _autoSyncOnStart();
    _restoreClockedInState();
  }

  @override
  void onClose() {
    _posStream?.cancel();
    _writeDebounceTimer?.cancel();
    _forcedPointTimer?.cancel();
    super.onClose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – CLOCK-IN HOOK
  // Call this from AttendanceViewModel right after saving the ATD record.
  // emp_id must already be written to SharedPreferences before calling.
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> onClockIn() async {
    final prefs = await SharedPreferences.getInstance();
    final empId = _readPref(prefs, 'emp_id');

    debugPrint('🟢 [LocVM] onClockIn → empId=$empId');

    // Reset tracking state
    totalDistance.value = 0.0;
    secondsPassed.value = 0;
    _lastTrackPoint     = null;
    _gpxInitialised     = false;
    _cachedDistance     = null;
    isClockedIn.value   = true;

    await _initGpxFile(empId: empId);
    await saveCurrentLocation();
    _startPositionStream();
    _startForcedPointTimer();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – CLOCK-OUT HOOK
  // Call this from AttendanceOutViewModel after saving the ATD-OUT record.
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> onClockOut() async {
    debugPrint('🔴 [LocVM] onClockOut → stopping GPX');

    await _stopPositionStream();
    _forcedPointTimer?.cancel();
    if (_pendingWrite) await _performFileWrite();

    final distance = _gpxInitialised && _gpxFile != null
        ? await _calculateDistanceFromFile(_gpxFile!.path)
        : 0.0;
    totalDistance.value = distance;

    if (_gpxInitialised) {
      await _saveLocationRecord(distance: distance);
    }

    isClockedIn.value   = false;
    secondsPassed.value = 0;
    unawaited(_trySync());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – LIVE LOCATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> saveCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _applyPosition(pos.latitude, pos.longitude);

      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final p   = marks.first;
        final adr = '${p.thoroughfare ?? ''} ${p.subLocality ?? ''}, '
            '${p.locality ?? ''} ${p.postalCode ?? ''}, ${p.country ?? ''}';
        address.value    = adr.trim().isEmpty ? 'Not Verified' : adr;
        shopAddress.value = address.value;
      }
    } catch (e) {
      debugPrint('❌ [LocVM] saveCurrentLocation: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – DISTANCE  (used by AttendanceOutViewModel & timer_card)
  // ─────────────────────────────────────────────────────────────────────────

  Future<double> getImmediateDistance() async {
    // Return cached value if still fresh
    if (_cachedDistance != null &&
        _lastDistanceCalc != null &&
        DateTime.now().difference(_lastDistanceCalc!) < _distanceCacheValidity) {
      return _cachedDistance!;
    }

    // Try live GPX file first
    if (_gpxInitialised && _gpxFile != null) {
      final d = await _fileLock
          .synchronized(() => _calculateDistanceFromFile(_gpxFile!.path));
      _cachedDistance   = d;
      _lastDistanceCalc = DateTime.now();
      return d;
    }

    // Fallback: find today's GPX file by convention
    try {
      final prefs   = await SharedPreferences.getInstance();
      final empId   = _readPref(prefs, 'emp_id');
      final date    = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final dir     = await getDownloadsDirectory();
      final path    = '${dir!.path}/track_${empId}_$date.gpx';
      final altPath = '${dir.path}/track_$date.gpx';

      for (final p in [path, altPath]) {
        if (await File(p).exists()) {
          final d = await _fileLock
              .synchronized(() => _calculateDistanceFromFile(p));
          _cachedDistance   = d;
          _lastDistanceCalc = DateTime.now();
          return d;
        }
      }
    } catch (e) {
      debugPrint('❌ [LocVM] getImmediateDistance fallback: $e');
    }

    return totalDistance.value;
  }

  Future<double> calculateShiftDistance(DateTime shiftStart) async {
    try {
      String? filePath;

      if (_gpxInitialised && _gpxFile != null) {
        filePath = _gpxFile!.path;
      } else {
        final prefs = await SharedPreferences.getInstance();
        final empId = _readPref(prefs, 'emp_id');
        final date  = DateFormat('dd-MM-yyyy').format(DateTime.now());
        final dir   = await getDownloadsDirectory();
        filePath = '${dir!.path}/track_${empId}_$date.gpx';
      }

      if (!await File(filePath!).exists()) return 0.0;

      final content = await _fileLock
          .synchronized(() => File(filePath!).readAsString());
      if (content.isEmpty) return 0.0;

      final gpx    = GpxReader().fromString(content);
      double total = 0.0;

      for (final trk in gpx.trks) {
        for (final seg in trk.trksegs) {
          final pts = seg.trkpts
              .where((p) => p.time != null && p.time!.isAfter(shiftStart))
              .toList();
          for (int i = 0; i < pts.length - 1; i++) {
            total += _distBetween(pts[i], pts[i + 1]);
          }
        }
      }
      return total;
    } catch (e) {
      debugPrint('❌ [LocVM] calculateShiftDistance: $e');
      return 0.0;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – GPX CONSOLIDATION  (called by timer_card.dart)
  // ─────────────────────────────────────────────────────────────────────────

  /// Merge all segment GPX files for [date] into a single daily file.
  Future<void> consolidateDailyGPXDataForDate(DateTime date) async {
    try {
      final dateStr = DateFormat('dd-MM-yyyy').format(date);
      final prefs   = await SharedPreferences.getInstance();
      final empId   = _readPref(prefs, 'emp_id');
      final dir     = await getDownloadsDirectory();
      final dailyPath = '${dir!.path}/track_${empId}_$dateStr.gpx';

      debugPrint('🔄 [LocVM] Consolidating GPX for: $dateStr');

      await _fileLock.synchronized(() async {
        final dailyFile = File(dailyPath);

        if (!await dailyFile.exists()) {
          await dailyFile.writeAsString(_blankGpx(dateStr));
        }

        // Collect every other .gpx for this date
        final segFiles = (await dir.list().toList())
            .whereType<File>()
            .where((f) =>
        f.path.endsWith('.gpx') &&
            f.path.contains(dateStr) &&
            f.path != dailyPath)
            .toList();

        if (segFiles.isEmpty) {
          debugPrint('📁 [LocVM] No segment files to merge');
          return;
        }

        final dailyContent = await dailyFile.readAsString();
        final dailyGpx     = GpxReader().fromString(dailyContent);

        if (dailyGpx.trks.isEmpty) dailyGpx.trks.add(Trk());
        if (dailyGpx.trks.first.trksegs.isEmpty) {
          dailyGpx.trks.first.trksegs.add(Trkseg());
        }

        final mainSeg   = dailyGpx.trks.first.trksegs.first;
        final existing  = <String>{};
        for (final pt in mainSeg.trkpts) {
          if (pt.lat != null && pt.lon != null && pt.time != null) {
            existing.add(
                '${pt.lat}_${pt.lon}_${pt.time!.millisecondsSinceEpoch}');
          }
        }

        int added = 0;
        for (final segFile in segFiles) {
          try {
            final segContent = await segFile.readAsString();
            final segGpx     = GpxReader().fromString(segContent);
            for (final trk in segGpx.trks) {
              for (final seg in trk.trksegs) {
                for (final pt in seg.trkpts) {
                  if (pt.lat != null &&
                      pt.lon != null &&
                      pt.time != null) {
                    final key =
                        '${pt.lat}_${pt.lon}_${pt.time!.millisecondsSinceEpoch}';
                    if (!existing.contains(key)) {
                      mainSeg.trkpts.add(pt);
                      existing.add(key);
                      added++;
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ [LocVM] Merge error ${segFile.path}: $e');
          }
        }

        // Sort by time
        mainSeg.trkpts.sort((a, b) {
          if (a.time == null || b.time == null) return 0;
          return a.time!.compareTo(b.time!);
        });

        await dailyFile.writeAsString(
            GpxWriter().asString(dailyGpx, pretty: true),
            flush: true);

        debugPrint('✅ [LocVM] Consolidated: +$added pts → $dailyPath');
      });
    } catch (e) {
      debugPrint('❌ [LocVM] consolidateDailyGPXDataForDate: $e');
    }
  }

  /// Convenience wrapper for today.
  Future<void> consolidateDailyGPXData() =>
      consolidateDailyGPXDataForDate(DateTime.now());

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – SAVE LOCATION FROM CONSOLIDATED FILE  (called by timer_card)
  // ─────────────────────────────────────────────────────────────────────────

  /// Read the consolidated daily GPX file for [date], calculate distance,
  /// insert a LocationModel row into the DB, and attempt server sync.
  Future<void> saveLocationFromConsolidatedFileForDate(DateTime date) async {
    try {
      final dateStr   = DateFormat('dd-MM-yyyy').format(date);
      final prefs     = await SharedPreferences.getInstance();
      final empId     = _readPref(prefs, 'emp_id');
      final empName   = _readPref(prefs, 'emp_name',
          fallbacks: ['empName', 'employee_name', 'name', 'userName']);
      final dir       = await getDownloadsDirectory();
      final filePath  = '${dir!.path}/track_${empId}_$dateStr.gpx';

      debugPrint('💾 [LocVM] Saving from consolidated file: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ [LocVM] File not found: $filePath');
        return;
      }

      final bytes    = await _fileLock
          .synchronized(() => file.readAsBytes());
      final distance = await _calculateDistanceFromFile(filePath);

      await _initSerialCounter();
      final locationId = _buildLocationId(empId: empId);

      final model = LocationModel(
        locationId    : locationId,
        locationDate  : DateFormat('yyyy-MM-dd').format(date),
        locationTime  : DateFormat('HH:mm:ss').format(date),
        fileName      : 'track_${empId}_$dateStr.gpx',
        empId         : empId,
        totalDistance : distance.toStringAsFixed(3),
        empName       : empName,
        posted        : 0,
        body          : Uint8List.fromList(bytes),
      );

      await _repo.add(model);
      await fetchAll();

      _serialCounter++;
      await _saveSerialCounter();

      unawaited(_trySync());

      debugPrint(
          '✅ [LocVM] Saved $locationId | ${distance.toStringAsFixed(3)} km');
    } catch (e) {
      debugPrint('❌ [LocVM] saveLocationFromConsolidatedFileForDate: $e');
    }
  }

  /// Convenience wrapper for today.
  Future<void> saveLocationFromConsolidatedFile() =>
      saveLocationFromConsolidatedFileForDate(DateTime.now());

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – DB OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> fetchAll() async {
    allLocations.value = await _repo.getAll();
  }

  Future<void> add(LocationModel model) async {
    await _repo.add(model);
    await fetchAll();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await fetchAll();
  }

  Future<void> syncNow() async {
    try {
      isLoading.value = true;
      await _repo.syncUnposted();
      await fetchAll();
      lastSyncTime.value = DateFormat('hh:mm a').format(DateTime.now());
      Get.snackbar('Sync Complete', 'Location data synced',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      debugPrint('❌ [LocVM] syncNow: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – GPX FILE INIT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initGpxFile({required String empId}) async {
    try {
      final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final dir  = await getDownloadsDirectory();
      final path = '${dir!.path}/track_${empId}_$date.gpx';

      _gpxFile = File(path);
      _gpx     = Gpx();
      _track   = Trk()..name = 'Track $date';
      _segment = Trkseg();
      _track!.trksegs.add(_segment!);
      _gpx!.trks.add(_track!);

      if (await _gpxFile!.exists()) {
        final content = await _gpxFile!.readAsString();
        if (content.isNotEmpty) {
          try {
            _gpx    = GpxReader().fromString(content);
            _track  = _gpx!.trks.isNotEmpty ? _gpx!.trks.first : _track;
            _segment = _track!.trksegs.isNotEmpty
                ? _track!.trksegs.last
                : Trkseg().._also(() => _track!.trksegs.add(_segment!));
            debugPrint(
                '📂 [LocVM] Loaded existing GPX (${_segment!.trkpts.length} pts)');
          } catch (_) {
            await _gpxFile!.writeAsString(_blankGpx(date), flush: true);
          }
        }
      } else {
        await _gpxFile!.writeAsString(_blankGpx(date), flush: true);
      }

      _gpxInitialised = true;
      debugPrint('✅ [LocVM] GPX ready: $path');
    } catch (e) {
      debugPrint('❌ [LocVM] _initGpxFile: $e');
    }
  }

  String _blankGpx(String date) => '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="GPS_Attendance">
  <trk><n>Track $date</n><trkseg></trkseg></trk>
</gpx>''';

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – POSITION STREAM
  // ─────────────────────────────────────────────────────────────────────────

  void _startPositionStream() {
    _posStream?.cancel();

    final settings = AndroidSettings(
      accuracy        : LocationAccuracy.high,
      distanceFilter  : 10,
      intervalDuration: const Duration(seconds: 30),
    );

    _posStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_handlePosition, onError: (e) {
      debugPrint('❌ [LocVM] Stream error: $e');
    });
    debugPrint('▶️ [LocVM] Position stream started');
  }

  Future<void> _stopPositionStream() async {
    await _posStream?.cancel();
    _posStream = null;
    debugPrint('⏹ [LocVM] Position stream stopped');
  }

  void _handlePosition(Position pos) {
    if (!_gpxInitialised || _segment == null) return;

    _applyPosition(pos.latitude, pos.longitude);

    final wpt = Wpt(
      lat : pos.latitude,
      lon : pos.longitude,
      time: pos.timestamp ?? DateTime.now(),
      ele : pos.altitude,
    );
    _segment!.trkpts.add(wpt);
    _lastTrackPoint = pos;

    if (_segment!.trkpts.length >= 2) {
      final prev = _segment!.trkpts[_segment!.trkpts.length - 2];
      totalDistance.value += _distBetween(prev, wpt);
      _cachedDistance      = null;
    }

    _debouncedWrite();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – FORCED POINT TIMER
  // ─────────────────────────────────────────────────────────────────────────

  void _startForcedPointTimer() {
    _forcedPointTimer?.cancel();
    _forcedPointTimer = Timer.periodic(
      const Duration(seconds: 60),
          (_) async {
        if (!_gpxInitialised || _lastTrackPoint == null || _segment == null) {
          return;
        }
        _segment!.trkpts.add(Wpt(
          lat : _lastTrackPoint!.latitude,
          lon : _lastTrackPoint!.longitude,
          time: DateTime.now(),
          name: 'heartbeat',
        ));
        _debouncedWrite();
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – FILE WRITE
  // ─────────────────────────────────────────────────────────────────────────

  void _debouncedWrite() {
    _pendingWrite = true;
    _writeDebounceTimer?.cancel();
    _writeDebounceTimer = Timer(_writeDebounce, _performFileWrite);
  }

  Future<void> _performFileWrite() async {
    if (!_pendingWrite || !_gpxInitialised || _gpxFile == null || _gpx == null) {
      return;
    }
    await _fileLock.synchronized(() async {
      try {
        await _gpxFile!.writeAsString(
            GpxWriter().asString(_gpx!, pretty: true),
            flush: true);
        _pendingWrite = false;
        debugPrint(
            '💾 [LocVM] GPX written – ${_segment?.trkpts.length ?? 0} pts');
      } catch (e) {
        debugPrint('❌ [LocVM] File write: $e');
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – SAVE LOCATION RECORD TO DB  (used by onClockOut)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _saveLocationRecord({required double distance}) async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final empId       = _readPref(prefs, 'emp_id');
      final empName     = _readPref(prefs, 'emp_name',
          fallbacks: ['empName', 'employee_name', 'name', 'userName']);
      final now         = DateTime.now();
      final dateStr     = DateFormat('yyyy-MM-dd').format(now);
      final timeStr     = DateFormat('HH:mm:ss').format(now);
      final fileDateStr = DateFormat('dd-MM-yyyy').format(now);

      // ── Accumulate previous sessions' distances for today ─────────────────
      // Find all existing DB records for this employee on today's date and sum
      // their distances. This handles multiple clock-in/clock-out cycles in a
      // single day: the new record will carry the full cumulative total.
      final todayRecords = await _repo.getByDate(dateStr);
      final previousTotal = todayRecords.fold<double>(
        0.0,
            (sum, r) => sum + (double.tryParse(r.totalDistance) ?? 0.0),
      );
      final cumulativeDistance = previousTotal + distance;

      debugPrint(
          '📊 [LocVM] Distance accumulation → previous: '
              '${previousTotal.toStringAsFixed(3)} km + '
              'this session: ${distance.toStringAsFixed(3)} km = '
              'cumulative: ${cumulativeDistance.toStringAsFixed(3)} km');

      await _initSerialCounter();
      final locationId = _buildLocationId(empId: empId);

      final bytes = (_gpxFile != null && _gpxFile!.existsSync())
          ? Uint8List.fromList(await _gpxFile!.readAsBytes())
          : null;

      final model = LocationModel(
        locationId    : locationId,
        locationDate  : dateStr,
        locationTime  : timeStr,
        fileName      : 'track_${empId}_$fileDateStr.gpx',
        empId         : empId,
        totalDistance : cumulativeDistance.toStringAsFixed(3),
        empName       : empName,
        posted        : 0,   // this new record will be synced
        body          : bytes,
      );

      await _repo.add(model);

      // ── Suppress older same-day records so only this one is synced ─────────
      // Mark every prior record for today as posted=1 so syncUnposted() skips
      // them. The server will only receive the latest cumulative record.
      await _repo.markOlderRecordsPosted(dateStr: dateStr, keepId: locationId);

      await fetchAll();

      _serialCounter++;
      await _saveSerialCounter();

      debugPrint(
          '✅ [LocVM] DB record saved: $locationId | '
              '${cumulativeDistance.toStringAsFixed(3)} km (cumulative)');
    } catch (e) {
      debugPrint('❌ [LocVM] _saveLocationRecord: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – SERIAL COUNTER
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initSerialCounter() async {
    final prefs    = await SharedPreferences.getInstance();
    _serialCounter = prefs.getInt('locationSerialCounter') ?? 1;
    _currentMonth  = prefs.getString('locationCurrentMonth')
        ?? DateFormat('MMM').format(DateTime.now());
    _currentEmpId  = _readPref(prefs, 'emp_id');
  }

  Future<void> _saveSerialCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('locationSerialCounter', _serialCounter);
    await prefs.setString('locationCurrentMonth', _currentMonth);
  }

  String _buildLocationId({required String empId}) {
    final now   = DateTime.now();
    final day   = DateFormat('dd').format(now);
    final month = DateFormat('MMM').format(now);

    if (_currentMonth != month) { _serialCounter = 1; _currentMonth = month; }
    if (_currentEmpId != empId) { _serialCounter = 1; _currentEmpId = empId; }

    final serial  = _serialCounter.toString().padLeft(3, '0');
    final empPart = empId.padLeft(2, '0');
    final id      = 'LOC-EMP-$empPart-$day-$month-$serial';
    debugPrint('🆔 [LocVM] ID: $id');
    return id;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – DISTANCE
  // ─────────────────────────────────────────────────────────────────────────

  Future<double> _calculateDistanceFromFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return 0.0;

      final content = await file.readAsString();
      if (content.isEmpty) return 0.0;

      final gpx    = GpxReader().fromString(content);
      double total = 0.0;

      for (final trk in gpx.trks) {
        for (final seg in trk.trksegs) {
          final pts = seg.trkpts;
          for (int i = 0; i < pts.length - 1; i++) {
            total += _distBetween(pts[i], pts[i + 1]);
          }
        }
      }
      return total;
    } catch (e) {
      debugPrint('⚠️ [LocVM] _calculateDistanceFromFile: $e');
      return 0.0;
    }
  }

  double _distBetween(Wpt a, Wpt b) {
    if (a.lat == null || a.lon == null || b.lat == null || b.lon == null) {
      return 0.0;
    }
    return Geolocator.distanceBetween(
      a.lat!.toDouble(), a.lon!.toDouble(),
      b.lat!.toDouble(), b.lon!.toDouble(),
    ) /
        1000.0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – RESTORE STATE ON RESTART
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _restoreClockedInState() async {
    final prefs        = await SharedPreferences.getInstance();
    final wasClockedIn = prefs.getBool('isClockedIn') ?? false;
    if (!wasClockedIn) return;

    debugPrint('🔄 [LocVM] Restoring GPS state…');
    final empId = _readPref(prefs, 'emp_id');
    isClockedIn.value = true;
    await _initGpxFile(empId: empId);
    _startPositionStream();
    _startForcedPointTimer();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – SYNC / CONNECTIVITY
  // ─────────────────────────────────────────────────────────────────────────

  void _autoSyncOnStart() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (await _isOnline()) {
        await _repo.syncUnposted();
        await fetchAll();
      }
    });
  }

  Future<void> _trySync() async {
    if (await _isOnline()) {
      await _repo.syncUnposted();
      await fetchAll();
    }
  }

  Future<bool> _isOnline() async {
    try {
      final res = await http
          .head(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  void _applyPosition(double lat, double lng) {
    latitude.value         = lat;
    longitude.value        = lng;
    globalLatitude1.value  = lat;
    globalLongitude1.value = lng;
  }

  String _readPref(
      SharedPreferences prefs,
      String key, {
        List<String> fallbacks = const [],
      }) {
    for (final k in [key, ...fallbacks]) {
      try {
        final raw = prefs.get(k);
        if (raw != null) {
          final val = raw.toString().trim();
          if (val.isNotEmpty) return val;
        }
      } catch (_) {}
    }
    return '';
  }
}

// ignore: unused_element
extension _Also on Object {
  void _also(void Function() block) => block();
}