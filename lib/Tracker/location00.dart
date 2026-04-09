

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gpx/gpx.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GPS Kalman Filter — eliminates jumps by blending noisy readings over time
// ─────────────────────────────────────────────────────────────────────────────
class GpsKalmanFilter {
  double _lat = 0;
  double _lon = 0;
  double _variance = -1; // negative = uninitialized

  static const double _minAccuracy = 1.0;

  bool get isInitialized => _variance >= 0;

  void init(double lat, double lon, double accuracy) {
    _lat = lat;
    _lon = lon;
    _variance = accuracy * accuracy;
  }

  /// Returns smoothed [lat, lon] given a new GPS reading.
  List<double> process(double lat, double lon, double accuracy, int timestampMs) {
    if (!isInitialized) {
      init(lat, lon, accuracy);
      return [lat, lon];
    }

    final accSq = max(accuracy, _minAccuracy) * max(accuracy, _minAccuracy);

    // Time-based process noise: more time = more uncertainty
    // 3 m/s² assumed movement noise
    const processNoise = 3.0;
    _variance += processNoise * processNoise;

    // Kalman gain
    final k = _variance / (_variance + accSq);

    // Correction
    _lat += k * (lat - _lat);
    _lon += k * (lon - _lon);
    _variance = (1 - k) * _variance;

    return [_lat, _lon];
  }

  void reset() {
    _variance = -1;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Outlier Detector — rejects impossible jumps
// ─────────────────────────────────────────────────────────────────────────────
class GpsOutlierDetector {
  static const double _maxReasonableSpeedMs = 14.0; // 50 km/h
  static const double _jumpThresholdMeters = 100.0; // >100m in <2s = jump

  double? _lastLat;
  double? _lastLon;
  DateTime? _lastTime;
  int _rejectedCount = 0;

  /// Returns true if this point looks like a real location (not a jump).
  bool isValid(double lat, double lon, double accuracy, DateTime time) {
    // Reject very inaccurate readings
    if (accuracy > 50.0) {
      debugPrint("🚫 Rejected: accuracy ${accuracy.toStringAsFixed(1)}m too low");
      return false;
    }

    if (_lastLat == null || _lastLon == null || _lastTime == null) {
      _update(lat, lon, time);
      return true;
    }

    final distanceM = Geolocator.distanceBetween(_lastLat!, _lastLon!, lat, lon);
    final elapsedSec = time.difference(_lastTime!).inMilliseconds / 1000.0;

    if (elapsedSec < 0.1) return false; // duplicate reading

    final speedMs = distanceM / elapsedSec;

    // Reject if speed is physically impossible
    if (speedMs > _maxReasonableSpeedMs) {
      _rejectedCount++;
      debugPrint("🚫 Rejected jump: ${distanceM.toStringAsFixed(1)}m in "
          "${elapsedSec.toStringAsFixed(1)}s = ${(speedMs * 3.6).toStringAsFixed(1)} km/h "
          "(rejected $_rejectedCount)");

      // After 3 consecutive rejects, accept anyway (GPS recovered to new position)
      if (_rejectedCount >= 3) {
        debugPrint("⚠️ 3 consecutive rejects — accepting new position as valid");
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
    _lastLat = lat;
    _lastLon = lon;
    _lastTime = time;
  }

  void reset() {
    _lastLat = null;
    _lastLon = null;
    _lastTime = null;
    _rejectedCount = 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LocationService
// ─────────────────────────────────────────────────────────────────────────────
class LocationService {
  late Gpx gpx;
  late Trk track;
  late Trkseg segment;
  late File file;
  late bool isFirstRun;
  late bool isConnected;
  late var lat, longi;
  late String userIdForLocation;
  late String userCityForLocatiion;
  late String userDesignationForLocation;
  late String userNameForLocation;
  late String rsmIdForLocation;
  late String nsmIdForLocation;
  late String smIdForLocation;
  late String dispatcherIdForLocation;
  late final Directory? downloadDirectory;
  late double totalDistance;
  Position? lastTrackPoint;
  String gpxString = "";

  bool _isInitialized = false;
  bool _isFirstLocationRecorded = false;
  Completer<void>? _initializationCompleter;
  List<Trkseg> _segments = [];
  final Lock _fileWriteLock = Lock();
  Timer? _writeDebounceTimer;
  Timer? _forcedUpdateTimer;
  static const Duration _writeDebounceDelay = Duration(seconds: 2);
  bool _pendingWrite = false;

  // ── Thresholds ──────────────────────────────────────────────────────────────
  static const double _minDistanceFilter = 3.0;   // metres — ignore micro-jitter
  static const int _maxTimeBetweenPoints = 10;    // seconds
  static const double _maxAcceptableAccuracy = 40.0;
  static const int _forcedPointIntervalSec = 30;  // only add forced point every 30s

  DateTime? _lastPointTime;
  int _consecutiveLowAccuracy = 0;

  // ── Anti-jump helpers ───────────────────────────────────────────────────────
  final GpsKalmanFilter _kalman = GpsKalmanFilter();
  final GpsOutlierDetector _outlierDetector = GpsOutlierDetector();

  LocationSettings? _locationSettings;

  LocationService() {
    totalDistance = 0.0;
    lastTrackPoint = null;
    _isInitialized = false;
    _isFirstLocationRecorded = false;
    _segments = [];
    init();
    lat = 0.0;
    longi = 0.0;
    isConnected = false;
  }

  StreamSubscription<Position>? positionStream;

  Future<void> _configureLocationSettings() async {
    _locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,           // bestForNavigation causes more jitter
      distanceFilter: 2,                         // OS-level pre-filter: ignore <2m moves
      forceLocationManager: false,               // prefer fused provider (smoother)
      intervalDuration: const Duration(seconds: 2),
    );
  }

  Future<void> listenLocation() async {
    if (!_isInitialized) {
      await _initializeService();
    }
    _startForcedUpdateTimer();
    positionStream = Geolocator.getPositionStream(
      locationSettings: _locationSettings!,
    ).listen((Position position) async {
      await _handleLocationUpdate(position);
    }, onError: (error) {
      debugPrint("❌ Location stream error: $error");
    });
  }

  void _startForcedUpdateTimer() {
    _forcedUpdateTimer?.cancel();
    _forcedUpdateTimer = Timer.periodic(
      const Duration(seconds: _forcedPointIntervalSec),
          (timer) async {
        if (lastTrackPoint != null && _lastPointTime != null) {
          int secondsSinceLast =
              DateTime.now().difference(_lastPointTime!).inSeconds;
          if (secondsSinceLast >= _forcedPointIntervalSec) {
            await _insertForcedPoint();
          }
        }
      },
    );
  }

  Future<void> _insertForcedPoint() async {
    if (lastTrackPoint == null) return;

    // Use Kalman-smoothed position, not raw lastTrackPoint
    final forcedPoint = Wpt(
      lat: _kalman.isInitialized
          ? _kalman.process(
        lastTrackPoint!.latitude,
        lastTrackPoint!.longitude,
        lastTrackPoint!.accuracy,
        DateTime.now().millisecondsSinceEpoch,
      )[0]
          : lastTrackPoint!.latitude,
      lon: _kalman.isInitialized
          ? _kalman.process(
        lastTrackPoint!.latitude,
        lastTrackPoint!.longitude,
        lastTrackPoint!.accuracy,
        DateTime.now().millisecondsSinceEpoch,
      )[1]
          : lastTrackPoint!.longitude,
      time: DateTime.now(),
      name: 'stationary',
    );

    segment.trkpts.add(forcedPoint);
    _lastPointTime = DateTime.now();
    debugPrint("⏰ Forced stationary point — total: ${segment.trkpts.length}");
    _debouncedUpdateGpxFile();
  }

  Future<void> checkAndStartNewSegment() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastClockOutTimeString = prefs.getString('lastClockOutTime');
    String? currentSessionStartString = prefs.getString('currentSessionStart');

    if (lastClockOutTimeString != null && currentSessionStartString != null) {
      DateTime lastClockOutTime = DateTime.parse(lastClockOutTimeString);
      DateTime currentSessionStart = DateTime.parse(currentSessionStartString);

      if (currentSessionStart.difference(lastClockOutTime).inMinutes > 30) {
        await _startNewSegment();
        // Reset filters for new segment
        _kalman.reset();
        _outlierDetector.reset();
        debugPrint("🔄 New GPX segment + filters reset");
      }
    }
  }

  Future<void> _startNewSegment() async {
    try {
      if (segment.trkpts.isNotEmpty) {
        _segments.add(segment);
      }
      segment = Trkseg();
      lastTrackPoint = null;

      if (track.trksegs.isEmpty) {
        track.trksegs = [segment];
      } else {
        track.trksegs.add(segment);
      }
      debugPrint("🔄 New GPX segment #${track.trksegs.length}");
    } catch (e) {
      debugPrint("❌ Error starting new segment: $e");
    }
  }

  Future<void> _initializeService() async {
    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }
    _initializationCompleter = Completer<void>();
    try {
      debugPrint("🔄 Initializing Location Service (Anti-Jump Mode)…");
      await _configureLocationSettings();
      await _loadUserData();
      await checkAndStartNewSegment();
      await _initializeGpxFile();
      await _waitForFirstValidLocation();
      _isInitialized = true;
      _initializationCompleter!.complete();
      debugPrint("✅ Location Service ready — Kalman + Outlier Rejection active");
    } catch (e) {
      debugPrint("❌ Init failed: $e");
      _initializationCompleter!.completeError(e);
    }
  }

  Future<void> _waitForFirstValidLocation() async {
    try {
      debugPrint("📍 Acquiring initial position…");
      Position? initialPosition;
      int attempts = 0;

      while (attempts < 20 && initialPosition == null) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 3),
          );
          if (pos.accuracy <= _maxAcceptableAccuracy) {
            initialPosition = pos;
          } else {
            debugPrint("⚠️ Accuracy ${pos.accuracy.toStringAsFixed(1)}m, retrying…");
            await Future.delayed(const Duration(seconds: 1));
          }
        } catch (_) {}
        attempts++;
      }

      initialPosition ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // Seed the Kalman filter with the first known-good position
      _kalman.init(
        initialPosition.latitude,
        initialPosition.longitude,
        initialPosition.accuracy,
      );
      _outlierDetector.reset();

      lat = initialPosition.latitude.toString();
      longi = initialPosition.longitude.toString();
      lastTrackPoint = initialPosition;
      _isFirstLocationRecorded = true;
      _lastPointTime = DateTime.now();

      debugPrint(
          "🎯 Initial fix: ${initialPosition.accuracy.toStringAsFixed(1)}m accuracy");
    } catch (e) {
      debugPrint("⚠️ Could not get initial position: $e");
      lastTrackPoint = null;
    }
  }

  Future<void> _loadUserData() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    await pref.reload();
    userNameForLocation = pref.getString("userName") ?? "USERName";
    userIdForLocation = pref.getString("userId") ?? "USERId";
    nsmIdForLocation = pref.getString("userNSM") ?? "nsmUSER";
    rsmIdForLocation = pref.getString("userRSM") ?? "rsmUSER";
    smIdForLocation = pref.getString("userSM") ?? "smUSER";
    dispatcherIdForLocation =
        pref.getString("userDISPATCHER") ?? "dispatcherUSER";
    userCityForLocatiion = pref.getString("userCity") ?? "CITY";
    userDesignationForLocation =
        pref.getString("userDesignation") ?? "DESIGNATION";
  }

  Future<void> _initializeGpxFile() async {
    try {
      gpx = Gpx();
      track = Trk();
      segment = Trkseg();
      _segments = [];

      final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
      downloadDirectory = await getDownloadsDirectory();
      final filePath =
          "${downloadDirectory!.path}/track_${userIdForLocation}_$date.gpx";
      file = File(filePath);

      if (await file.exists()) {
        String existingContent = await file.readAsString();
        if (existingContent.trim().isNotEmpty) {
          try {
            Gpx existingGpx = GpxReader().fromString(existingContent);
            if (existingGpx.trks.isNotEmpty) {
              gpx.trks = existingGpx.trks;
              track = gpx.trks[0];
              if (track.trksegs.isNotEmpty) {
                _segments = List<Trkseg>.from(track.trksegs);
                segment = track.trksegs.last;
              } else {
                track.trksegs.add(segment);
              }
              isFirstRun = false;
              totalDistance = await _calculateDistanceFromExistingFile();
              debugPrint(
                  "📂 Loaded GPX: ${totalDistance.toStringAsFixed(3)} km, "
                      "${_getTotalPoints()} pts");
            } else {
              _createNewGpxStructure();
            }
          } catch (e) {
            debugPrint("⚠️ Corrupted GPX, creating new: $e");
            _createNewGpxStructure();
          }
        } else {
          _createNewGpxStructure();
        }
      } else {
        _createNewGpxStructure();
      }
    } catch (e) {
      debugPrint('❌ Error initializing GPX: $e');
      _createNewGpxStructure();
    }
  }

  Future<double> _calculateDistanceFromExistingFile() async {
    try {
      if (!await file.exists()) return 0.0;
      String gpxContent = await file.readAsString();
      if (gpxContent.isEmpty) return 0.0;
      Gpx existingGpx = GpxReader().fromString(gpxContent);
      double existingDistance = 0.0;
      for (var trk in existingGpx.trks) {
        for (var seg in trk.trksegs) {
          if (seg.trkpts.length < 2) continue;
          for (int i = 0; i < seg.trkpts.length - 1; i++) {
            existingDistance += calculateDistance(
              seg.trkpts[i].lat?.toDouble() ?? 0.0,
              seg.trkpts[i].lon?.toDouble() ?? 0.0,
              seg.trkpts[i + 1].lat?.toDouble() ?? 0.0,
              seg.trkpts[i + 1].lon?.toDouble() ?? 0.0,
            );
          }
        }
      }
      return existingDistance;
    } catch (e) {
      debugPrint("❌ Error calculating existing distance: $e");
      return 0.0;
    }
  }

  void _createNewGpxStructure() {
    gpx = Gpx();
    track = Trk();
    segment = Trkseg();
    _segments = [];
    track.trksegs.add(segment);
    gpx.trks.add(track);
    isFirstRun = true;
    file.createSync(recursive: true);
    totalDistance = 0.0;
    debugPrint("📁 New GPX file created");
  }

  // ── Core: handle each incoming GPS position ─────────────────────────────────
  Future<void> _handleLocationUpdate(Position position) async {
    final now = DateTime.now();

    // ── Step 1: Accuracy gate ────────────────────────────────────────────────
    if (position.accuracy > _maxAcceptableAccuracy) {
      _consecutiveLowAccuracy++;
      debugPrint("⚠️ Low accuracy ${position.accuracy.toStringAsFixed(1)}m "
          "($_consecutiveLowAccuracy/5)");
      if (_consecutiveLowAccuracy <= 5) return; // skip until GPS stabilises
    } else {
      _consecutiveLowAccuracy = 0;
    }

    // ── Step 2: Outlier / jump rejection ────────────────────────────────────
    if (!_outlierDetector.isValid(
        position.latitude, position.longitude, position.accuracy, now)) {
      return; // impossible jump — discard
    }

    // ── Step 3: Kalman smoothing ─────────────────────────────────────────────
    final smoothed = _kalman.process(
      position.latitude,
      position.longitude,
      position.accuracy,
      now.millisecondsSinceEpoch,
    );
    final smoothLat = smoothed[0];
    final smoothLon = smoothed[1];

    // Update public lat/lon with smoothed values
    lat = smoothLat.toString();
    longi = smoothLon.toString();

    // ── Step 4: Distance + time gate ────────────────────────────────────────
    bool shouldAddPoint = false;
    double segmentDistance = 0.0;
    int secondsSinceLast = _lastPointTime != null
        ? now.difference(_lastPointTime!).inSeconds
        : 999;

    if (lastTrackPoint != null) {
      // Measure distance from last *recorded* smoothed point
      segmentDistance = calculateDistance(
        lastTrackPoint!.latitude,
        lastTrackPoint!.longitude,
        smoothLat,
        smoothLon,
      );

      final movedEnough = segmentDistance * 1000 >= _minDistanceFilter;
      final timeExpired = secondsSinceLast >= _maxTimeBetweenPoints;

      if (movedEnough || timeExpired) {
        shouldAddPoint = true;
        if (movedEnough) totalDistance += segmentDistance;
        debugPrint(
            "📍 ${timeExpired && !movedEnough ? '⏰ TIME' : '📏 DIST'} | "
                "Δ${(segmentDistance * 1000).toStringAsFixed(1)}m | "
                "${secondsSinceLast}s | "
                "acc ${position.accuracy.toStringAsFixed(1)}m | "
                "${totalDistance.toStringAsFixed(3)} km | "
                "${_getTotalPoints()} pts");
      }
    } else {
      shouldAddPoint = true;
      debugPrint("🎯 First point (acc ${position.accuracy.toStringAsFixed(1)}m)");
    }

    // ── Step 5: Write track point using SMOOTHED coordinates ────────────────
    if (shouldAddPoint) {
      final trackPoint = Wpt(
        lat: smoothLat,
        lon: smoothLon,
        time: now,
        ele: position.altitude,
        name: (position.speed * 3.6) > 1.0 ? 'moving' : 'stationary',
      );

      segment.trkpts.add(trackPoint);
      _lastPointTime = now;

      // Update lastTrackPoint with smoothed coordinates for next distance calc
      lastTrackPoint = Position(
        latitude: smoothLat,
        longitude: smoothLon,
        accuracy: position.accuracy,
        altitude: position.altitude,
        altitudeAccuracy: position.altitudeAccuracy ?? 0,
        heading: position.heading,
        headingAccuracy: position.headingAccuracy ?? 0,
        speed: position.speed,
        speedAccuracy: position.speedAccuracy ?? 0,
        timestamp: position.timestamp,
      );

      if (segment.trkpts.length > 5000) {
        await _startNewSegment();
      }

      _debouncedUpdateGpxFile();
    } else {
      // Still update lastTrackPoint's raw reference for outlier detector
      lastTrackPoint = Position(
        latitude: smoothLat,
        longitude: smoothLon,
        accuracy: position.accuracy,
        altitude: position.altitude,
        altitudeAccuracy: position.altitudeAccuracy ?? 0,
        heading: position.heading,
        headingAccuracy: position.headingAccuracy ?? 0,
        speed: position.speed,
        speedAccuracy: position.speedAccuracy ?? 0,
        timestamp: position.timestamp,
      );
    }
  }

  void _debouncedUpdateGpxFile() {
    _pendingWrite = true;
    _writeDebounceTimer?.cancel();
    _writeDebounceTimer = Timer(_writeDebounceDelay, _performFileWrite);
  }

  Future<void> _performFileWrite() async {
    if (!_pendingWrite) return;
    await _fileWriteLock.synchronized(() async {
      try {
        if (_segments.isNotEmpty) {
          track.trksegs = List<Trkseg>.from(_segments);
          if (!track.trksegs.contains(segment)) {
            track.trksegs.add(segment);
          }
        }
        gpxString = GpxWriter().asString(gpx, pretty: true);
        await file.writeAsString(gpxString, flush: true);
        _pendingWrite = false;
        debugPrint("💾 GPX: ${track.trksegs.length} segs | "
            "${_getTotalPoints()} pts | "
            "${(await file.length() / 1024).toStringAsFixed(1)} KB");
      } catch (e) {
        debugPrint('❌ Error writing GPX: $e');
      }
    });
  }

  double getCurrentDistance() =>
      double.parse(totalDistance.toStringAsFixed(3));

  Future<double> calculateCurrentDistance() async {
    try {
      if (!await file.exists()) return totalDistance;
      String gpxContent = await file.readAsString();
      if (gpxContent.isEmpty) return totalDistance;

      Gpx g = GpxReader().fromString(gpxContent);
      double calc = 0.0;
      for (var trk in g.trks) {
        for (var seg in trk.trksegs) {
          if (seg.trkpts.length < 2) continue;
          for (int i = 0; i < seg.trkpts.length - 1; i++) {
            calc += calculateDistance(
              seg.trkpts[i].lat?.toDouble() ?? 0.0,
              seg.trkpts[i].lon?.toDouble() ?? 0.0,
              seg.trkpts[i + 1].lat?.toDouble() ?? 0.0,
              seg.trkpts[i + 1].lon?.toDouble() ?? 0.0,
            );
          }
        }
      }
      totalDistance = calc > totalDistance ? calc : totalDistance;
      return totalDistance;
    } catch (e) {
      debugPrint('❌ Error calculating distance: $e');
      return totalDistance;
    }
  }

  int _getTotalPoints() {
    int total = 0;
    for (var seg in track.trksegs) {
      total += seg.trkpts.length;
    }
    return total;
  }

  Future<void> init() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    await pref.reload();
    userNameForLocation = pref.getString("userName") ?? "USERName";
    userIdForLocation = pref.getString("userId") ?? "USERId";
    nsmIdForLocation = pref.getString("userNSM") ?? "nsmUSER";
    rsmIdForLocation = pref.getString("userRSM") ?? "rsmUSER";
    smIdForLocation = pref.getString("userSM") ?? "smUSER";
    dispatcherIdForLocation =
        pref.getString("userDISPATCHER") ?? "dispatcherUSER";
    userCityForLocatiion = pref.getString("userCity") ?? "CITY";
    userDesignationForLocation =
        pref.getString("userDesignation") ?? "DESIGNATION";
  }

  double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000.0;
  }

  Future<void> stopListening() async {
    try {
      positionStream?.cancel();
      _forcedUpdateTimer?.cancel();
      _writeDebounceTimer?.cancel();
      if (_pendingWrite) await _performFileWrite();
      await calculateCurrentDistance();

      SharedPreferences pref = await SharedPreferences.getInstance();
      await pref.setDouble("TotalDistance", totalDistance);
      await pref.setString(
          "lastSessionEnd", DateTime.now().toIso8601String());

      debugPrint(
          "🛑 Stopped. ${totalDistance.toStringAsFixed(3)} km | ${_getTotalPoints()} pts");
    } catch (e) {
      debugPrint("❌ ERROR in stopListening: $e");
    }
  }

  void resetDistance() {
    totalDistance = 0.0;
    _kalman.reset();
    _outlierDetector.reset();
    debugPrint("🔄 Distance + filters reset");
  }

  Map<String, dynamic> getServiceStatus() {
    return {
      'isInitialized': _isInitialized,
      'isFirstLocationRecorded': _isFirstLocationRecorded,
      'totalDistance': totalDistance,
      'pointsRecorded': segment.trkpts.length,
      'totalSegments': track.trksegs.length,
      'totalAllPoints': _getTotalPoints(),
      'lastTrackPoint': lastTrackPoint != null
          ? '${lastTrackPoint!.latitude.toStringAsFixed(6)}, '
          '${lastTrackPoint!.longitude.toStringAsFixed(6)}'
          : 'None',
      'filePath': file.path,
      'fileExists': file.existsSync(),
      'fileSize': file.existsSync() ? file.lengthSync() : 0,
      'pendingWrite': _pendingWrite,
      'mode': 'KALMAN_SMOOTH',
      'accuracy': lastTrackPoint?.accuracy,
      'kalmanInitialized': _kalman.isInitialized,
    };
  }

  Future<String> getGpxContent() async {
    try {
      if (await file.exists()) return await file.readAsString();
      return gpxString;
    } catch (e) {
      debugPrint("❌ Error reading GPX: $e");
      return "";
    }
  }

  Future<String> getConsolidatedGpx() async {
    try {
      Gpx consolidated = Gpx();
      Trk consolidatedTrack = Trk()
        ..name = "Track ${DateFormat('dd-MM-yyyy').format(DateTime.now())}";
      for (var seg in track.trksegs) {
        if (seg.trkpts.isNotEmpty) consolidatedTrack.trksegs.add(seg);
      }
      consolidated.trks.add(consolidatedTrack);
      return GpxWriter().asString(consolidated, pretty: true);
    } catch (e) {
      debugPrint("❌ Error consolidating GPX: $e");
      return gpxString;
    }
  }

  Future<void> saveGpxFile(String filePath) async {
    try {
      File outputFile = File(filePath);
      String content = await getConsolidatedGpx();
      await outputFile.writeAsString(content, flush: true);
      debugPrint("💾 GPX saved: $filePath");
    } catch (e) {
      debugPrint("❌ Error saving GPX: $e");
    }
  }
}