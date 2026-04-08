
import 'dart:async';
import 'dart:io';
import 'dart:math';
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

import '../Database/db_helper.dart';
import '../Models/location_model.dart';
import '../Repositories/location_repository.dart';
import '../Tracker/fake_gps_log.dart'; // ✅ ADDED

// ─────────────────────────────────────────────────────────────────────────────
// GPS Kalman Filter  (ported from location00.dart)
// Blends noisy GPS readings over time; eliminates the zigzag that inflates
// distance by 30–200 %.
// ─────────────────────────────────────────────────────────────────────────────
class GpsKalmanFilter {
  double _lat      = 0;
  double _lon      = 0;
  double _variance = -1; // negative = uninitialised

  static const double _minAccuracy = 1.0;

  bool get isInitialized => _variance >= 0;

  void init(double lat, double lon, double accuracy) {
    _lat      = lat;
    _lon      = lon;
    _variance = accuracy * accuracy;
  }

  /// Returns smoothed [lat, lon] pair.
  List<double> process(double lat, double lon, double accuracy, int timestampMs) {
    if (!isInitialized) {
      init(lat, lon, accuracy);
      return [lat, lon];
    }

    final accSq = max(accuracy, _minAccuracy) * max(accuracy, _minAccuracy);

    // Process noise: assume up to 3 m/s² movement uncertainty
    const processNoise = 3.0;
    _variance += processNoise * processNoise;

    // Kalman gain
    final k = _variance / (_variance + accSq);

    // Correction
    _lat      += k * (lat - _lat);
    _lon      += k * (lon - _lon);
    _variance  = (1 - k) * _variance;

    return [_lat, _lon];
  }

  void reset() => _variance = -1;
}

// ─────────────────────────────────────────────────────────────────────────────
// GPS Outlier Detector  (ported from location00.dart)
// Rejects impossible position jumps caused by multipath or satellite switches.
// After 3 consecutive rejects it accepts the new position (GPS recovered).
// ─────────────────────────────────────────────────────────────────────────────
class GpsOutlierDetector {
  // 50 km/h = 13.9 m/s  →  reasonable for walking / city traffic
  static const double _maxReasonableSpeedMs = 13.9;

  double?   _lastLat;
  double?   _lastLon;
  DateTime? _lastTime;
  int       _rejectedCount = 0;

  /// Returns true if this point is a plausible real location.
  bool isValid(double lat, double lon, double accuracy, DateTime time) {
    // Reject very inaccurate fixes
    if (accuracy > 50.0) {
      debugPrint('🚫 [Outlier] accuracy ${accuracy.toStringAsFixed(1)} m > 50 m — rejected');
      return false;
    }

    if (_lastLat == null || _lastLon == null || _lastTime == null) {
      _update(lat, lon, time);
      return true;
    }

    final distM    = Geolocator.distanceBetween(_lastLat!, _lastLon!, lat, lon);
    final elapsedS = time.difference(_lastTime!).inMilliseconds / 1000.0;

    if (elapsedS < 0.1) return false; // duplicate reading

    final speedMs = distM / elapsedS;

    if (speedMs > _maxReasonableSpeedMs) {
      _rejectedCount++;
      debugPrint('🚫 [Outlier] ${distM.toStringAsFixed(1)} m in '
          '${elapsedS.toStringAsFixed(1)} s = '
          '${(speedMs * 3.6).toStringAsFixed(1)} km/h '
          '(rejected $_rejectedCount)');

      // After 3 consecutive rejects, accept anyway — GPS recovered to new pos
      if (_rejectedCount >= 3) {
        debugPrint('⚠️ [Outlier] 3 consecutive rejects — accepting new position');
        _rejectedCount = 0;
        _update(lat, lon, time);
        return true;
      }
      return false;
    }

    _rejectedCount = 0;
    _update(lat, lon, time);
    return true;
  }

  void _update(double lat, double lon, DateTime time) {
    _lastLat  = lat;
    _lastLon  = lon;
    _lastTime = time;
  }

  void reset() {
    _lastLat       = null;
    _lastLon       = null;
    _lastTime      = null;
    _rejectedCount = 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LocationViewModel
// ─────────────────────────────────────────────────────────────────────────────
class LocationViewModel extends GetxController {
  // ── Dependency ────────────────────────────────────────────────────────────
  final LocationRepository _repo = LocationRepository();

  // ── Observables – GPS ─────────────────────────────────────────────────────
  var latitude         = 0.0.obs;
  var longitude        = 0.0.obs;
  var address          = ''.obs;
  var globalLatitude1  = 0.0.obs; // backward-compat alias
  var globalLongitude1 = 0.0.obs; // backward-compat alias
  var shopAddress      = ''.obs;  // backward-compat alias

  // ── Observables – state ───────────────────────────────────────────────────
  var isClockedIn   = false.obs;
  var secondsPassed = 0.obs;       // used by trac.dart
  var totalDistance = 0.0.obs;     // km – live in-memory accumulator
  var isLoading     = false.obs;
  var lastSyncTime  = ''.obs;

  // ── Observables – DB records ──────────────────────────────────────────────
  var allLocations = <LocationModel>[].obs;

  // ── Internal – GPX ───────────────────────────────────────────────────────
  Gpx?      _gpx;
  Trk?      _track;
  Trkseg?   _segment;
  File?     _gpxFile;
  bool      _gpxInitialised = false;
  Position? _lastTrackPoint; // always stores SMOOTHED coordinates

  // ── GPS filters (from location00) ─────────────────────────────────────────
  final GpsKalmanFilter    _kalman          = GpsKalmanFilter();
  final GpsOutlierDetector _outlierDetector = GpsOutlierDetector();

  // ── GPS thresholds ────────────────────────────────────────────────────────
  static const double _maxAccuracyMeters  = 40.0; // drop if worse than 40 m
  static const double _minDistanceMeters  = 3.0;  // ignore micro-jitter < 3 m
  static const int    _maxSecsBetweenPts  = 10;   // time-gate: add pt every 10 s
  static const int    _forcedPointIntervalSec = 30; // heartbeat every 30 s

  DateTime? _lastPointTime;
  int       _consecutiveLowAccuracy = 0;

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
  static const Duration         _writeDebounce     = Duration(seconds: 2);

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
    FakeGpsLog.syncPending(); // ✅ ADDED — upload any offline fake-GPS events
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
  // Call from AttendanceViewModel after saving the ATD record.
  // emp_id must already be written to SharedPreferences before calling.
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> onClockIn() async {
    final prefs = await SharedPreferences.getInstance();
    final empId = _readPref(prefs, 'emp_id');

    debugPrint('🟢 [LocVM] onClockIn → empId=$empId');

    // Reset all state cleanly
    totalDistance.value    = 0.0;
    secondsPassed.value    = 0;
    _lastTrackPoint        = null;
    _lastPointTime         = null;
    _gpxInitialised        = false;
    _cachedDistance        = null;
    _consecutiveLowAccuracy = 0;
    _kalman.reset();
    _outlierDetector.reset();
    isClockedIn.value      = true;

    await _initGpxFile(empId: empId);

    // Get first accurate fix and seed the Kalman filter
    await _acquireInitialFix();

    _startPositionStream();
    _startForcedPointTimer();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – CLOCK-OUT HOOK
  // Call from AttendanceOutViewModel after saving the ATD-OUT record.
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> onClockOut() async {
    debugPrint('🔴 [LocVM] onClockOut → stopping GPX');

    await _stopPositionStream();
    _forcedPointTimer?.cancel();
    if (_pendingWrite) await _performFileWrite();

    // Authoritative distance comes from the GPX file (excludes heartbeats)
    final distance = _gpxInitialised && _gpxFile != null
        ? await _calculateDistanceFromFile(_gpxFile!.path)
        : totalDistance.value;

    totalDistance.value = distance;

    if (_gpxInitialised) {
      await _saveLocationRecord(distance: distance);
    }

    isClockedIn.value   = false;
    secondsPassed.value = 0;
    _kalman.reset();
    _outlierDetector.reset();
    unawaited(_trySync());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – LIVE LOCATION (address resolution)
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
        address.value     = adr.trim().isEmpty ? 'Not Verified' : adr;
        shopAddress.value = address.value;
      }
    } catch (e) {
      debugPrint('❌ [LocVM] saveCurrentLocation: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – DISTANCE  (used by AttendanceOutViewModel & timer_card)
  // ─────────────────────────────────────────────────────────────────────────

  /// While clocked-in, returns the in-memory accumulator (no file I/O).
  /// After clock-out, reads from the GPX file with a 5-second cache.
  Future<double> getImmediateDistance() async {
    if (isClockedIn.value && _gpxInitialised) {
      return totalDistance.value;
    }

    // Cached value still fresh?
    if (_cachedDistance != null &&
        _lastDistanceCalc != null &&
        DateTime.now().difference(_lastDistanceCalc!) < _distanceCacheValidity) {
      return _cachedDistance!;
    }

    // Try live GPX file
    if (_gpxInitialised && _gpxFile != null) {
      final d = await _fileLock
          .synchronized(() => _calculateDistanceFromFile(_gpxFile!.path));
      _cachedDistance   = d;
      _lastDistanceCalc = DateTime.now();
      return d;
    }

    // Fallback: find today's GPX file by naming convention
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
        filePath    = '${dir!.path}/track_${empId}_$date.gpx';
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
              .where((p) =>
          p.time != null &&
              p.time!.isAfter(shiftStart) &&
              p.name != 'heartbeat' &&   // exclude heartbeats
              p.name != 'stationary')    // exclude stationary forced pts
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
  // PUBLIC – GPX CONSOLIDATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> consolidateDailyGPXDataForDate(DateTime date) async {
    try {
      final dateStr   = DateFormat('dd-MM-yyyy').format(date);
      final prefs     = await SharedPreferences.getInstance();
      final empId     = _readPref(prefs, 'emp_id');
      final dir       = await getDownloadsDirectory();
      final dailyPath = '${dir!.path}/track_${empId}_$dateStr.gpx';

      debugPrint('🔄 [LocVM] Consolidating GPX for: $dateStr');

      await _fileLock.synchronized(() async {
        final dailyFile = File(dailyPath);

        if (!await dailyFile.exists()) {
          await dailyFile.writeAsString(_blankGpx(dateStr));
        }

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

        final mainSeg  = dailyGpx.trks.first.trksegs.first;
        final existing = <String>{};
        for (final pt in mainSeg.trkpts) {
          if (pt.lat != null && pt.lon != null && pt.time != null) {
            existing
                .add('${pt.lat}_${pt.lon}_${pt.time!.millisecondsSinceEpoch}');
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
                      pt.time != null &&
                      pt.name != 'heartbeat' &&  // skip heartbeats
                      pt.name != 'stationary') { // skip forced stationary pts
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

  Future<void> consolidateDailyGPXData() =>
      consolidateDailyGPXDataForDate(DateTime.now());

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – SAVE LOCATION FROM CONSOLIDATED FILE  (called by timer_card)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> saveLocationFromConsolidatedFileForDate(DateTime date) async {
    try {
      final dateStr  = DateFormat('dd-MM-yyyy').format(date);
      final prefs    = await SharedPreferences.getInstance();
      final empId    = _readPref(prefs, 'emp_id');
      final empName  = _readPref(prefs, 'emp_name',
          fallbacks: ['empName', 'employee_name', 'name', 'userName']);
      final dir      = await getDownloadsDirectory();
      final filePath = '${dir!.path}/track_${empId}_$dateStr.gpx';

      debugPrint('💾 [LocVM] Saving from consolidated file: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ [LocVM] File not found: $filePath');
        return;
      }

      final bytes    = await _fileLock.synchronized(() => file.readAsBytes());
      final distance = await _calculateDistanceFromFile(filePath);

      await _initSerialCounter();
      final locationId = _buildLocationId(empId: empId);

      final model = LocationModel(
        locationId   : locationId,
        locationDate : DateFormat('yyyy-MM-dd').format(date),
        locationTime : DateFormat('HH:mm:ss').format(date),
        fileName     : 'track_${empId}_$dateStr.gpx',
        empId        : empId,
        totalDistance: distance.toStringAsFixed(3),
        empName      : empName,
        posted       : 0,
        body         : Uint8List.fromList(bytes),
        company_code : DBHelper.getCompanyCode(),
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
  // PRIVATE – INITIAL FIX  (seeds Kalman filter before streaming starts)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _acquireInitialFix() async {
    try {
      debugPrint('📍 [LocVM] Acquiring initial GPS fix…');
      Position? initialPosition;
      int attempts = 0;

      while (attempts < 20 && initialPosition == null) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 3),
          );
          if (pos.accuracy <= _maxAccuracyMeters) {
            initialPosition = pos;
          } else {
            debugPrint(
                '⚠️ [LocVM] Accuracy ${pos.accuracy.toStringAsFixed(1)} m — retrying…');
            await Future.delayed(const Duration(seconds: 1));
          }
        } catch (_) {
          await Future.delayed(const Duration(seconds: 1));
        }
        attempts++;
      }

      // Fallback — accept any fix if we couldn't get a good one
      initialPosition ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // Seed Kalman with the best known-good position
      _kalman.init(
        initialPosition.latitude,
        initialPosition.longitude,
        initialPosition.accuracy,
      );
      _outlierDetector.reset();

      _applyPosition(initialPosition.latitude, initialPosition.longitude);
      _lastTrackPoint = initialPosition;
      _lastPointTime  = DateTime.now();

      debugPrint(
          '🎯 [LocVM] Initial fix: ${initialPosition.accuracy.toStringAsFixed(1)} m accuracy');
    } catch (e) {
      debugPrint('⚠️ [LocVM] Could not acquire initial fix: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – GPX FILE INIT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initGpxFile({required String empId, bool restore = false}) async {
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
            final existing = GpxReader().fromString(content);
            _gpx   = existing;
            _track = existing.trks.isNotEmpty ? existing.trks.first : _track;

            if (restore) {
              // On app-restart restore, start a FRESH segment so stale
              // heartbeat / duplicate points are never re-measured.
              _segment = Trkseg();
              _track!.trksegs.add(_segment!);

              // Restore distance from file so the UI shows the correct total
              totalDistance.value = await _calculateDistanceFromFile(path);
            } else {
              _segment = _track!.trksegs.isNotEmpty
                  ? _track!.trksegs.last
                  : Trkseg();
              if (!_track!.trksegs.contains(_segment)) {
                _track!.trksegs.add(_segment!);
              }
            }

            debugPrint(
                '📂 [LocVM] Loaded existing GPX (${_getTotalPoints()} pts)');
          } catch (_) {
            // Corrupt file — start fresh
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
  <trk>
    <name>Track $date</name>
    <trkseg></trkseg>
  </trk>
</gpx>''';

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – POSITION STREAM
  // ─────────────────────────────────────────────────────────────────────────

  void _startPositionStream() {
    _posStream?.cancel();

    // Settings from location00: 2 m filter, 2 s interval — dense + smooth track
    final settings = AndroidSettings(
      accuracy        : LocationAccuracy.high,
      distanceFilter  : 2,                          // 2 m (was 5 m)
      forceLocationManager: false,                  // use fused provider (smoother)
      intervalDuration: const Duration(seconds: 2), // 2 s (was 15 s)
    );

    _posStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_handlePosition, onError: (e) {
      debugPrint('❌ [LocVM] Stream error: $e');
    });
    debugPrint('▶️ [LocVM] Position stream started (Kalman + Outlier active)');
  }

  Future<void> _stopPositionStream() async {
    await _posStream?.cancel();
    _posStream = null;
    debugPrint('⏹ [LocVM] Position stream stopped');
  }

  // ── Core: handle each incoming GPS position ────────────────────────────────

  void _handlePosition(Position pos) {
    FakeGpsLog.checkAndReport(pos); // ✅ ADDED — detect fake GPS on every update
    if (!_gpxInitialised || _segment == null) return;

    final now = DateTime.now();

    // ── Step 1: Accuracy gate ──────────────────────────────────────────────
    if (pos.accuracy > _maxAccuracyMeters) {
      _consecutiveLowAccuracy++;
      debugPrint('⚠️ [LocVM] Low accuracy ${pos.accuracy.toStringAsFixed(1)} m '
          '($_consecutiveLowAccuracy/5)');
      if (_consecutiveLowAccuracy <= 5) return; // skip until GPS stabilises
    } else {
      _consecutiveLowAccuracy = 0;
    }

    // ── Step 2: Outlier / jump rejection ──────────────────────────────────
    if (!_outlierDetector.isValid(
        pos.latitude, pos.longitude, pos.accuracy, now)) {
      return; // impossible jump — discard
    }

    // ── Step 3: Kalman smoothing ───────────────────────────────────────────
    final smoothed = _kalman.process(
      pos.latitude,
      pos.longitude,
      pos.accuracy,
      now.millisecondsSinceEpoch,
    );
    final smoothLat = smoothed[0];
    final smoothLon = smoothed[1];

    _applyPosition(smoothLat, smoothLon);

    // ── Step 4: Distance + time gate ──────────────────────────────────────
    bool   shouldAddPoint   = false;
    double segmentDistanceM = 0.0;
    int    secondsSinceLast = _lastPointTime != null
        ? now.difference(_lastPointTime!).inSeconds
        : 999;

    if (_lastTrackPoint != null) {
      segmentDistanceM = Geolocator.distanceBetween(
        _lastTrackPoint!.latitude, _lastTrackPoint!.longitude,
        smoothLat, smoothLon,
      );

      final movedEnough = segmentDistanceM >= _minDistanceMeters;
      final timeExpired = secondsSinceLast >= _maxSecsBetweenPts;

      if (movedEnough || timeExpired) {
        shouldAddPoint = true;

        // Only accumulate distance when user actually moved
        if (movedEnough) {
          totalDistance.value += segmentDistanceM / 1000.0; // m → km
          _cachedDistance      = null;
        }

        debugPrint(
            '📍 [LocVM] ${timeExpired && !movedEnough ? '⏰ TIME' : '📏 DIST'} | '
                'Δ${segmentDistanceM.toStringAsFixed(1)} m | '
                '${secondsSinceLast}s | '
                'acc ${pos.accuracy.toStringAsFixed(1)} m | '
                '${totalDistance.value.toStringAsFixed(3)} km | '
                '${_getTotalPoints()} pts');
      }
    } else {
      shouldAddPoint = true;
      debugPrint('🎯 [LocVM] First point (acc ${pos.accuracy.toStringAsFixed(1)} m)');
    }

    // ── Step 5: Write track point using SMOOTHED coordinates ──────────────
    if (shouldAddPoint) {
      final wpt = Wpt(
        lat : smoothLat,
        lon : smoothLon,
        time: now,
        ele : pos.altitude,
        name: (pos.speed * 3.6) > 1.0 ? 'moving' : 'stationary_motion',
      );
      _segment!.trkpts.add(wpt);
      _lastPointTime = now;

      // Update lastTrackPoint with SMOOTHED coordinates for next distance calc
      _lastTrackPoint = Position(
        latitude        : smoothLat,
        longitude       : smoothLon,
        accuracy        : pos.accuracy,
        altitude        : pos.altitude,
        altitudeAccuracy: pos.altitudeAccuracy ?? 0,
        heading         : pos.heading,
        headingAccuracy : pos.headingAccuracy ?? 0,
        speed           : pos.speed,
        speedAccuracy   : pos.speedAccuracy ?? 0,
        timestamp       : pos.timestamp,
      );

      // Auto-split segment at 5000 points to keep file size manageable
      if (_segment!.trkpts.length > 5000) {
        _segment = Trkseg();
        _track!.trksegs.add(_segment!);
        debugPrint('🔄 [LocVM] New GPX segment #${_track!.trksegs.length}');
      }

      _debouncedWrite();
    } else {
      // Still update lastTrackPoint reference (for outlier detector continuity)
      _lastTrackPoint = Position(
        latitude        : smoothLat,
        longitude       : smoothLon,
        accuracy        : pos.accuracy,
        altitude        : pos.altitude,
        altitudeAccuracy: pos.altitudeAccuracy ?? 0,
        heading         : pos.heading,
        headingAccuracy : pos.headingAccuracy ?? 0,
        speed           : pos.speed,
        speedAccuracy   : pos.speedAccuracy ?? 0,
        timestamp       : pos.timestamp,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – FORCED / HEARTBEAT POINT TIMER
  // Every 30 s: inserts a Kalman-smoothed point tagged 'heartbeat'.
  // Distance calculation ALWAYS skips heartbeat points.
  // ─────────────────────────────────────────────────────────────────────────

  void _startForcedPointTimer() {
    _forcedPointTimer?.cancel();
    _forcedPointTimer = Timer.periodic(
      const Duration(seconds: _forcedPointIntervalSec),
          (_) async {
        if (!_gpxInitialised || _lastTrackPoint == null || _segment == null) {
          return;
        }

        // Use Kalman-smoothed position, not raw lastTrackPoint
        final smoothed = _kalman.isInitialized
            ? _kalman.process(
          _lastTrackPoint!.latitude,
          _lastTrackPoint!.longitude,
          _lastTrackPoint!.accuracy,
          DateTime.now().millisecondsSinceEpoch,
        )
            : [_lastTrackPoint!.latitude, _lastTrackPoint!.longitude];

        _segment!.trkpts.add(Wpt(
          lat : smoothed[0],
          lon : smoothed[1],
          time: DateTime.now(),
          name: 'heartbeat', // ALWAYS skipped by distance calculation
        ));
        // Do NOT add to totalDistance — no movement occurred
        _debouncedWrite();
        debugPrint('⏰ [LocVM] Heartbeat point — total: ${_getTotalPoints()} pts');
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
            '💾 [LocVM] GPX written – ${_getTotalPoints()} pts '
                '| ${totalDistance.value.toStringAsFixed(3)} km');
      } catch (e) {
        debugPrint('❌ [LocVM] File write: $e');
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – DISTANCE (file-based, used at clock-out + consolidation)
  // Heartbeat and stationary forced points are excluded.
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
          // Exclude heartbeats AND stationary forced points
          final pts = seg.trkpts
              .where((p) =>
          p.name != 'heartbeat' &&
              p.name != 'stationary')
              .toList();
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
        1000.0; // m → km
  }

  int _getTotalPoints() {
    int n = 0;
    _track?.trksegs.forEach((s) => n += s.trkpts.length);
    return n;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – SAVE LOCATION RECORD TO DB
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

      // Cumulative = sum of ALREADY POSTED sessions + this session.
      // We never double-count the current session.
      final todayRecords   = await _repo.getByDate(dateStr);
      final previousTotal  = todayRecords
          .where((r) => r.posted == 1)
          .fold<double>(
          0.0, (sum, r) => sum + (double.tryParse(r.totalDistance) ?? 0.0));
      final cumulativeDistance = previousTotal + distance;

      debugPrint(
          '📊 [LocVM] Distance → previous: ${previousTotal.toStringAsFixed(3)} km '
              '+ this session: ${distance.toStringAsFixed(3)} km '
              '= cumulative: ${cumulativeDistance.toStringAsFixed(3)} km');

      await _initSerialCounter();
      final locationId = _buildLocationId(empId: empId);

      final bytes = (_gpxFile != null && _gpxFile!.existsSync())
          ? Uint8List.fromList(await _gpxFile!.readAsBytes())
          : null;

      final model = LocationModel(
        locationId   : locationId,
        locationDate : dateStr,
        locationTime : timeStr,
        fileName     : 'track_${empId}_$fileDateStr.gpx',
        empId        : empId,
        totalDistance: cumulativeDistance.toStringAsFixed(3),
        empName      : empName,
        posted       : 0,
        body         : bytes,
        company_code : DBHelper.getCompanyCode(),
      );

      await _repo.add(model);

      // Mark older same-day records so only the latest cumulative is synced
      await _repo.markOlderRecordsPosted(
          dateStr: dateStr, keepId: locationId);

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

    if (_currentMonth != month) {
      _serialCounter = 1;
      _currentMonth  = month;
    }
    if (_currentEmpId != empId) {
      _serialCounter = 1;
      _currentEmpId  = empId;
    }

    final serial      = _serialCounter.toString().padLeft(3, '0');
    final empPart     = empId.padLeft(2, '0');
    final companyCode = DBHelper.getCompanyCode() ?? '';

    final id = companyCode.isNotEmpty
        ? '$companyCode-LOC-EMP-$empPart-$day-$month-$serial'
        : 'LOC-EMP-$empPart-$day-$month-$serial';

    debugPrint('🆔 [LocVM] ID: $id (company: $companyCode)');
    return id;
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

    _kalman.reset();
    _outlierDetector.reset();

    // restore: true → new segment so stale heartbeats are never re-measured
    await _initGpxFile(empId: empId, restore: true);
    await _acquireInitialFix();
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