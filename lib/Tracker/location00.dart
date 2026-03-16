// // // import 'dart:async';
// // // import 'dart:io';
// // // import 'package:cloud_firestore/cloud_firestore.dart';
// // // import 'package:firebase_core/firebase_core.dart';
// // // import 'package:flutter/foundation.dart';
// // // import 'package:geolocator/geolocator.dart';
// // // import 'package:gpx/gpx.dart';
// // // import 'package:intl/intl.dart';
// // // import 'package:order_booking_app/Databases/util.dart';
// // // import 'package:path_provider/path_provider.dart';
// // // import 'package:shared_preferences/shared_preferences.dart';
// // // import 'package:synchronized/synchronized.dart';
// // // import 'package:permission_handler/permission_handler.dart';
// // //
// // // class LocationService {
// // //   late Gpx gpx;
// // //   late Trk track;
// // //   late Trkseg segment;
// // //   late File file;
// // //   late bool isFirstRun;
// // //   late bool isConnected;
// // //   late var lat, longi;
// // //   late String userIdForLocation;
// // //   late String userCityForLocatiion;
// // //   late String userDesignationForLocation;
// // //   late String userNameForLocation;
// // //   late String rsmIdForLocation;
// // //   late String nsmIdForLocation;
// // //   late String smIdForLocation;
// // //   late String dispatcherIdForLocation;
// // //   late final Directory? downloadDirectory;
// // //   late double totalDistance;
// // //   Position? lastTrackPoint;
// // //   String gpxString = "";
// // //
// // //   bool _isInitialized = false;
// // //   bool _isFirstLocationRecorded = false;
// // //   Completer<void>? _initializationCompleter;
// // //   List<Trkseg> _segments = [];
// // //   final Lock _fileWriteLock = Lock();
// // //   Timer? _writeDebounceTimer;
// // //   Timer? _forcedUpdateTimer; // ✅ NEW: Forces points even when stationary
// // //   Timer? _firebaseUpdateTimer;   // ✅ Add here
// // //   Position? _latestPosition;      // ✅ Add here
// // //   static const Duration _writeDebounceDelay = Duration(seconds: 1);
// // //   bool _pendingWrite = false;
// // //
// // //   // ✅ ULTRA SETTINGS: Maximum accuracy configuration
// // //   static const double _minDistanceFilter = 1.0; // 1 meter - maximum density
// // //   static const int _maxTimeBetweenPoints = 5; // Force point every 5 seconds
// // //   static const double _maxAcceptableAccuracy = 20.0; // Allow up to 20m (urban canyons)
// // //   static const double _maxSpeedThreshold = 60.0; // 216 km/h - filter impossible speeds
// // //
// // //   DateTime? _lastPointTime;
// // //   int _consecutiveLowAccuracy = 0;
// // //
// // //   LocationSettings? _locationSettings; // Will be configured for raw GPS
// // //
// // //   LocationService() {
// // //     totalDistance = 0.0;
// // //     lastTrackPoint = null;
// // //     _isInitialized = false;
// // //     _isFirstLocationRecorded = false;
// // //     _segments = [];
// // //     init();
// // //     Firebase.initializeApp();
// // //     lat = 0.0;
// // //     longi = 0.0;
// // //     isConnected = false;
// // //   }
// // //
// // //   StreamSubscription<Position>? positionStream;
// // //
// // //   /// ✅ CONFIGURE FOR RAW GPS - Maximum accuracy
// // //   Future<void> _configureLocationSettings() async {
// // //     // For Android: Use bestForNavigation with minimal filtering
// // //     // This bypasses FLP and uses raw GNSS when possible
// // //
// // //     _locationSettings = AndroidSettings(
// // //       accuracy: LocationAccuracy.high,
// // //       distanceFilter: 10, // optional: 10 meter movement detect kare
// // //       forceLocationManager: false,
// // //       intervalDuration: const Duration(minutes: 1), // ✅ MAIN CHANGE
// // //
// // //     // _locationSettings = AndroidSettings(
// // //     //   accuracy: LocationAccuracy.bestForNavigation, // Raw GPS, no FLP fusion
// // //     //   distanceFilter: 1, // 1 meter - capture every tiny movement
// // //     //   forceLocationManager: true, // Force raw GPS, ignore FLP
// // //     //   intervalDuration: const Duration(seconds: 1), // Check every second
// // //       // foregroundNotificationConfig: const ForegroundNotificationConfig(
// // //       //   notificationText: 'Ultra GPS Tracking Active',
// // //       //   notificationTitle: 'Recording precise location',
// // //       //   enableWakeLock: true, // Keep CPU awake for accuracy
// // //       // ),
// // //     );
// // //   }
// // //
// // //   Future<void> listenLocation() async {
// // //     if (!_isInitialized) {
// // //       await _initializeService();
// // //     }
// // //
// // //     // ✅ Start forced update timer (captures points even when stopped at turns)
// // //     _startForcedUpdateTimer();
// // //
// // //     positionStream = Geolocator.getPositionStream(locationSettings: _locationSettings!)
// // //         .listen((Position position) async {
// // //       await _handleLocationUpdate(position);
// // //     }, onError: (error) {
// // //       debugPrint("❌ Location stream error: $error");
// // //     });
// // //   }
// // //
// // //   /// ✅ Forces a point every 5 seconds even if not moved (captures stopped time at intersections)
// // //   void _startForcedUpdateTimer() {
// // //     _forcedUpdateTimer?.cancel();
// // //     _forcedUpdateTimer = Timer.periodic(
// // //       const Duration(seconds: _maxTimeBetweenPoints),
// // //           (timer) async {
// // //         if (lastTrackPoint != null && _lastPointTime != null) {
// // //           int secondsSinceLast = DateTime.now().difference(_lastPointTime!).inSeconds;
// // //           if (secondsSinceLast >= _maxTimeBetweenPoints) {
// // //             // Force insert a point at current location to maintain timeline
// // //             await _insertForcedPoint();
// // //           }
// // //         }
// // //       },
// // //     );
// // //   }
// // //
// // //   /// ✅ Inserts a point even if we haven't moved (maintains track continuity)
// // //   Future<void> _insertForcedPoint() async {
// // //     if (lastTrackPoint == null) return;
// // //
// // //     final forcedPoint = Wpt(
// // //       lat: lastTrackPoint!.latitude,
// // //       lon: lastTrackPoint!.longitude,
// // //       time: DateTime.now(),
// // //       // Add metadata to identify forced points
// // //       name: 'forced',
// // //     );
// // //
// // //     segment.trkpts.add(forcedPoint);
// // //     _lastPointTime = DateTime.now();
// // //
// // //     debugPrint("⏰ Forced point inserted at ${segment.trkpts.length} total points");
// // //     _debouncedUpdateGpxFile();
// // //   }
// // //
// // //   Future<void> checkAndStartNewSegment() async {
// // //     SharedPreferences prefs = await SharedPreferences.getInstance();
// // //     String? lastClockOutTimeString = prefs.getString('lastClockOutTime');
// // //     String? currentSessionStartString = prefs.getString('currentSessionStart');
// // //
// // //     if (lastClockOutTimeString != null && currentSessionStartString != null) {
// // //       DateTime lastClockOutTime = DateTime.parse(lastClockOutTimeString);
// // //       DateTime currentSessionStart = DateTime.parse(currentSessionStartString);
// // //
// // //       if (currentSessionStart.difference(lastClockOutTime).inMinutes > 30) {
// // //         await _startNewSegment();
// // //         debugPrint("🔄 Starting new GPX segment");
// // //       }
// // //     }
// // //   }
// // //
// // //   Future<void> _startNewSegment() async {
// // //     try {
// // //       if (segment.trkpts.isNotEmpty) {
// // //         _segments.add(segment);
// // //       }
// // //
// // //       segment = Trkseg();
// // //       lastTrackPoint = null; // Reset to force new first point
// // //
// // //       if (track.trksegs.isEmpty) {
// // //         track.trksegs = [segment];
// // //       } else {
// // //         track.trksegs.add(segment);
// // //       }
// // //
// // //       debugPrint("🔄 Started new GPX segment #${track.trksegs.length}");
// // //     } catch (e) {
// // //       debugPrint("❌ Error starting new segment: $e");
// // //     }
// // //   }
// // //
// // //   Future<void> _initializeService() async {
// // //     if (_initializationCompleter != null) {
// // //       return _initializationCompleter!.future;
// // //     }
// // //
// // //     _initializationCompleter = Completer<void>();
// // //
// // //     try {
// // //       debugPrint("🔄 Initializing Ultra Location Service...");
// // //       await _configureLocationSettings(); // ✅ Configure raw GPS
// // //       await _loadUserData();
// // //       await checkAndStartNewSegment();
// // //       await _initializeGpxFile();
// // //       await _waitForFirstValidLocation();
// // //
// // //       _isInitialized = true;
// // //       _initializationCompleter!.complete();
// // //       debugPrint("✅ Ultra Location Service Initialized - Raw GPS Mode");
// // //     } catch (e) {
// // //       debugPrint("❌ Initialization Failed: $e");
// // //       _initializationCompleter!.completeError(e);
// // //     }
// // //   }
// // //
// // //   Future<void> _waitForFirstValidLocation() async {
// // //     try {
// // //       debugPrint("📍 Acquiring ultra-precise initial fix...");
// // //
// // //       // Try to get best possible initial fix
// // //       Position? initialPosition;
// // //       int attempts = 0;
// // //       const maxAttempts = 30; // 30 seconds max
// // //
// // //       while (attempts < maxAttempts && initialPosition == null) {
// // //         try {
// // //           initialPosition = await Geolocator.getCurrentPosition(
// // //             desiredAccuracy: LocationAccuracy.bestForNavigation,
// // //             timeLimit: const Duration(seconds: 2),
// // //           );
// // //
// // //           // Only accept if accuracy is good enough
// // //           if (initialPosition.accuracy > _maxAcceptableAccuracy) {
// // //             debugPrint("⚠️ Initial fix accuracy ${initialPosition.accuracy}m, retrying...");
// // //             initialPosition = null;
// // //             await Future.delayed(const Duration(seconds: 1));
// // //           }
// // //         } catch (e) {
// // //           // Timeout or error, retry
// // //         }
// // //         attempts++;
// // //       }
// // //
// // //       if (initialPosition == null) {
// // //         // Fallback to any position
// // //         initialPosition = await Geolocator.getCurrentPosition(
// // //           desiredAccuracy: LocationAccuracy.high,
// // //         );
// // //       }
// // //
// // //       lat = initialPosition.latitude.toString();
// // //       longi = initialPosition.longitude.toString();
// // //
// // //       lastTrackPoint = Position(
// // //         latitude: initialPosition.latitude,
// // //         longitude: initialPosition.longitude,
// // //         accuracy: initialPosition.accuracy,
// // //         altitude: initialPosition.altitude,
// // //         altitudeAccuracy: initialPosition.altitudeAccuracy ?? 0,
// // //         heading: initialPosition.heading,
// // //         headingAccuracy: initialPosition.headingAccuracy ?? 0,
// // //         speed: initialPosition.speed,
// // //         speedAccuracy: initialPosition.speedAccuracy ?? 0,
// // //         timestamp: initialPosition.timestamp,
// // //       );
// // //
// // //       _isFirstLocationRecorded = true;
// // //       _lastPointTime = DateTime.now();
// // //       debugPrint("🎯 Ultra-precise initial fix: ${initialPosition.accuracy}m accuracy");
// // //     } catch (e) {
// // //       debugPrint("⚠️ Could not get initial position: $e");
// // //       lastTrackPoint = null;
// // //     }
// // //   }
// // //
// // //   Future<void> _loadUserData() async {
// // //     SharedPreferences pref = await SharedPreferences.getInstance();
// // //     await pref.reload();
// // //
// // //     userNameForLocation = pref.getString("userName") ?? "USERName";
// // //     userIdForLocation = pref.getString("userId") ?? "USERId";
// // //     nsmIdForLocation = pref.getString("userNSM") ?? "nsmUSER";
// // //     rsmIdForLocation = pref.getString("userRSM") ?? "rsmUSER";
// // //     smIdForLocation = pref.getString("userSM") ?? "smUSER";
// // //     dispatcherIdForLocation = pref.getString("userDISPATCHER") ?? "dispatcherUSER";
// // //     userCityForLocatiion = pref.getString("userCity") ?? "CITY";
// // //     userDesignationForLocation = pref.getString("userDesignation") ?? "DESIGNATION";
// // //   }
// // //
// // //   Future<void> _initializeGpxFile() async {
// // //     try {
// // //       gpx = Gpx();
// // //       track = Trk();
// // //       segment = Trkseg();
// // //       _segments = [];
// // //
// // //       final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
// // //       downloadDirectory = await getDownloadsDirectory();
// // //
// // //       final filePath = "${downloadDirectory!.path}/track_${userIdForLocation}_$date.gpx";
// // //       file = File(filePath);
// // //
// // //       if (await file.exists()) {
// // //         String existingContent = await file.readAsString();
// // //         if (existingContent.trim().isNotEmpty) {
// // //           try {
// // //             Gpx existingGpx = GpxReader().fromString(existingContent);
// // //             if (existingGpx.trks.isNotEmpty) {
// // //               gpx.trks = existingGpx.trks;
// // //               track = gpx.trks[0];
// // //
// // //               if (track.trksegs.isNotEmpty) {
// // //                 _segments = List<Trkseg>.from(track.trksegs);
// // //                 segment = track.trksegs.last;
// // //               } else {
// // //                 track.trksegs.add(segment);
// // //               }
// // //
// // //               isFirstRun = false;
// // //               totalDistance = await _calculateDistanceFromExistingFile();
// // //               debugPrint("📂 Existing GPX loaded: ${totalDistance.toStringAsFixed(3)} km, ${_getTotalPoints()} points");
// // //             } else {
// // //               _createNewGpxStructure();
// // //             }
// // //           } catch (e) {
// // //             debugPrint("⚠️ Corrupted GPX file, creating new: $e");
// // //             _createNewGpxStructure();
// // //           }
// // //         } else {
// // //           _createNewGpxStructure();
// // //         }
// // //       } else {
// // //         _createNewGpxStructure();
// // //       }
// // //     } catch (e) {
// // //       debugPrint('❌ Error initializing GPX file: $e');
// // //       _createNewGpxStructure();
// // //     }
// // //   }
// // //
// // //   Future<double> _calculateDistanceFromExistingFile() async {
// // //     try {
// // //       if (!await file.exists()) return 0.0;
// // //       String gpxContent = await file.readAsString();
// // //       if (gpxContent.isEmpty) return 0.0;
// // //
// // //       Gpx existingGpx = GpxReader().fromString(gpxContent);
// // //       double existingDistance = 0.0;
// // //
// // //       for (var trk in existingGpx.trks) {
// // //         for (var seg in trk.trksegs) {
// // //           if (seg.trkpts.length < 2) continue;
// // //           for (int i = 0; i < seg.trkpts.length - 1; i++) {
// // //             double distance = calculateDistance(
// // //               seg.trkpts[i].lat?.toDouble() ?? 0.0,
// // //               seg.trkpts[i].lon?.toDouble() ?? 0.0,
// // //               seg.trkpts[i + 1].lat?.toDouble() ?? 0.0,
// // //               seg.trkpts[i + 1].lon?.toDouble() ?? 0.0,
// // //             );
// // //             existingDistance += distance;
// // //           }
// // //         }
// // //       }
// // //       return existingDistance;
// // //     } catch (e) {
// // //       debugPrint("❌ Error calculating existing distance: $e");
// // //       return 0.0;
// // //     }
// // //   }
// // //
// // //   void _createNewGpxStructure() {
// // //     gpx = Gpx();
// // //     track = Trk();
// // //     segment = Trkseg();
// // //     _segments = [];
// // //
// // //     track.trksegs.add(segment);
// // //     gpx.trks.add(track);
// // //
// // //     isFirstRun = true;
// // //     file.createSync(recursive: true);
// // //     totalDistance = 0.0;
// // //     debugPrint("📁 Created new ultra-precision GPX file");
// // //   }
// // //
// // //   /// ✅ ULTRA-HANDLER: Maximum accuracy with intelligent filtering
// // //   Future<void> _handleLocationUpdate(Position position) async {
// // //     // ✅ RELAXED accuracy check - accept up to 20m (urban canyons cause reflections)
// // //     if (position.accuracy > _maxAcceptableAccuracy) {
// // //       _consecutiveLowAccuracy++;
// // //       if (_consecutiveLowAccuracy > 5) {
// // //         debugPrint("⚠️ Too many low accuracy readings (${position.accuracy}m), accepting anyway");
// // //         // Continue processing despite low accuracy after 5 consecutive bad readings
// // //       } else {
// // //         debugPrint("⚠️ Low accuracy: ${position.accuracy}m, skipping (${_consecutiveLowAccuracy}/5)");
// // //         return;
// // //       }
// // //     } else {
// // //       _consecutiveLowAccuracy = 0; // Reset counter on good reading
// // //     }
// // //
// // //     // ✅ Speed check - filter impossible speeds (60 m/s = 216 km/h)
// // //     if (position.speed > _maxSpeedThreshold) {
// // //       debugPrint("⚠️ Impossible speed: ${(position.speed * 3.6).toStringAsFixed(1)} km/h");
// // //       return;
// // //     }
// // //
// // //     lat = position.latitude.toString();
// // //     longi = position.longitude.toString();
// // //
// // //     final trackPoint = Wpt(
// // //       lat: position.latitude,
// // //       lon: position.longitude,
// // //       time: DateTime.now(),
// // //       ele: position.altitude,
// // //       // Store additional metadata in GPX
// // //       name: position.speed > 0.5 ? 'moving' : 'stationary',
// // //     );
// // //
// // //     bool shouldAddPoint = false;
// // //     double segmentDistance = 0.0;
// // //     int secondsSinceLastPoint = _lastPointTime != null
// // //         ? DateTime.now().difference(_lastPointTime!).inSeconds
// // //         : 999;
// // //
// // //     if (lastTrackPoint != null) {
// // //       segmentDistance = calculateDistance(
// // //         lastTrackPoint!.latitude,
// // //         lastTrackPoint!.longitude,
// // //         position.latitude,
// // //         position.longitude,
// // //       );
// // //
// // //       // ✅ ULTRA LOGIC: Add point if moved 1m+ OR if 5+ seconds passed
// // //       // This captures micro-movements and maintains density at stops
// // //       if (segmentDistance >= _minDistanceFilter || secondsSinceLastPoint >= _maxTimeBetweenPoints) {
// // //         shouldAddPoint = true;
// // //
// // //         if (segmentDistance >= _minDistanceFilter) {
// // //           totalDistance += segmentDistance;
// // //         }
// // //
// // //         debugPrint("📍 ${secondsSinceLastPoint >= _maxTimeBetweenPoints ? '⏰ TIME' : '📏 DIST'} | "
// // //             "Moved: ${(segmentDistance * 1000).toStringAsFixed(1)}m | "
// // //             "Time: ${secondsSinceLastPoint}s | "
// // //             "Acc: ${position.accuracy.toStringAsFixed(1)}m | "
// // //             "Total: ${totalDistance.toStringAsFixed(3)} km | "
// // //             "Points: ${_getTotalPoints()}");
// // //       }
// // //     } else {
// // //       shouldAddPoint = true;
// // //       debugPrint("🎯 First ultra-precise point added (${position.accuracy}m accuracy)");
// // //     }
// // //
// // //     if (shouldAddPoint) {
// // //       segment.trkpts.add(trackPoint);
// // //       _lastPointTime = DateTime.now();
// // //
// // //       // ✅ Larger segment size for ultra-density (5000 points = ~5km at 1m intervals)
// // //       if (segment.trkpts.length > 5000) {
// // //         await _startNewSegment();
// // //       }
// // //
// // //       _debouncedUpdateGpxFile();
// // //     }
// // //
// // //     // ✅ Always update lastTrackPoint for heading/speed calculations
// // //     lastTrackPoint = Position(
// // //       latitude: position.latitude,
// // //       longitude: position.longitude,
// // //       accuracy: position.accuracy,
// // //       altitude: position.altitude,
// // //       altitudeAccuracy: position.altitudeAccuracy ?? 0,
// // //       heading: position.heading,
// // //       headingAccuracy: position.headingAccuracy ?? 0,
// // //       speed: position.speed,
// // //       speedAccuracy: position.speedAccuracy ?? 0,
// // //       timestamp: position.timestamp,
// // //     );
// // //
// // //     // await _updateFirebase(position);
// // //     _latestPosition = position;
// // //
// // //     if (_firebaseUpdateTimer == null || !_firebaseUpdateTimer!.isActive) {
// // //       _firebaseUpdateTimer = Timer(const Duration(minutes: 1), () async {
// // //         if (_latestPosition != null) {
// // //           await _updateFirebase(_latestPosition!);
// // //         }
// // //       });
// // //     }
// // //   }
// // //
// // //   void _debouncedUpdateGpxFile() {
// // //     _pendingWrite = true;
// // //     _writeDebounceTimer?.cancel();
// // //     _writeDebounceTimer = Timer(_writeDebounceDelay, () {
// // //       _performFileWrite();
// // //     });
// // //   }
// // //
// // //   Future<void> _performFileWrite() async {
// // //     if (!_pendingWrite) return;
// // //
// // //     await _fileWriteLock.synchronized(() async {
// // //       try {
// // //         if (_segments.isNotEmpty) {
// // //           track.trksegs = List<Trkseg>.from(_segments);
// // //           if (!track.trksegs.contains(segment)) {
// // //             track.trksegs.add(segment);
// // //           }
// // //         }
// // //
// // //         // ✅ Pretty print for debugging, compact for production
// // //         gpxString = GpxWriter().asString(gpx, pretty: true);
// // //         await file.writeAsString(gpxString, flush: true);
// // //         _pendingWrite = false;
// // //
// // //         debugPrint("💾 GPX Saved: ${track.trksegs.length} segments, ${_getTotalPoints()} points, "
// // //             "${(await file.length() / 1024).toStringAsFixed(1)} KB");
// // //       } catch (e) {
// // //         debugPrint('❌ Error writing GPX: $e');
// // //       }
// // //     });
// // //   }
// // //
// // //   // Future<void> _updateFirebase(Position position) async {
// // //   //   isConnected = await isNetworkAvailableForFirebase();
// // //   //
// // //   //   if (isConnected) {
// // //   //     try {
// // //   //       await FirebaseFirestore.instance
// // //   //           .collection('location')
// // //   //           .doc(userIdForLocation.toString())
// // //   //           .set({
// // //   //         'latitude': position.latitude,
// // //   //         'longitude': position.longitude,
// // //   //         'name': userNameForLocation.toString(),
// // //   //         'userId': userIdForLocation.toString(),
// // //   //         'city': userCityForLocatiion.toString(),
// // //   //         'designation': userDesignationForLocation.toString(),
// // //   //         'RSM_ID': rsmIdForLocation.toString(),
// // //   //         'NSM_ID': nsmIdForLocation.toString(),
// // //   //         'SM_ID': smIdForLocation.toString(),
// // //   //         'DISPATCHER_ID': dispatcherIdForLocation.toString(),
// // //   //         'isActive': true,
// // //   //         'totalDistance': totalDistance,
// // //   //         'accuracy': position.accuracy,
// // //   //         'speed': position.speed * 3.6,
// // //   //         'altitude': position.altitude,
// // //   //         'heading': position.heading,
// // //   //         'segments': track.trksegs.length,
// // //   //         'points': _getTotalPoints(),
// // //   //         'lastUpdate': FieldValue.serverTimestamp(),
// // //   //         'trackingMode': 'ultra', // Identify this as high-accuracy track
// // //   //       }, SetOptions(merge: true));
// // //   //     } catch (e) {
// // //   //       debugPrint('❌ Firebase update error: $e');
// // //   //     }
// // //   //   }
// // //   // }
// // //   ///28-02-2026
// // //   Future<void> _updateFirebase(Position position) async {
// // //     isConnected = await isNetworkAvailableForFirebase();
// // //
// // //     if (isConnected) {
// // //       try {
// // //         await FirebaseFirestore.instance
// // //             .collection('location')
// // //             .doc(userIdForLocation.toString())
// // //             .set({
// // //           'latitude': position.latitude,
// // //           'longitude': position.longitude,
// // //           'name': userNameForLocation.toString(),
// // //           'userId': userIdForLocation.toString(),
// // //           'city': userCityForLocatiion.toString(),
// // //           'designation': userDesignationForLocation.toString(),
// // //           'RSM_ID': rsmIdForLocation.toString(),
// // //           'NSM_ID': nsmIdForLocation.toString(),
// // //           'SM_ID': smIdForLocation.toString(),
// // //           'DISPATCHER_ID': dispatcherIdForLocation.toString(),
// // //           'isActive': true,
// // //           'totalDistance': totalDistance,
// // //         }, SetOptions(merge: true));
// // //       } catch (e) {
// // //         debugPrint('❌ Firebase update error: $e');
// // //       }
// // //     }
// // //   }
// // //
// // //   double getCurrentDistance() {
// // //     return double.parse(totalDistance.toStringAsFixed(3));
// // //   }
// // //
// // //   Future<double> calculateCurrentDistance() async {
// // //     try {
// // //       double memoryDistance = totalDistance;
// // //
// // //       if (!await file.exists()) return memoryDistance;
// // //
// // //       String gpxContent = await file.readAsString();
// // //       if (gpxContent.isEmpty) return memoryDistance;
// // //
// // //       Gpx gpx = GpxReader().fromString(gpxContent);
// // //       double calculatedDistance = 0.0;
// // //
// // //       for (var trk in gpx.trks) {
// // //         for (var seg in trk.trksegs) {
// // //           if (seg.trkpts.length < 2) continue;
// // //           for (int i = 0; i < seg.trkpts.length - 1; i++) {
// // //             double distance = calculateDistance(
// // //               seg.trkpts[i].lat?.toDouble() ?? 0.0,
// // //               seg.trkpts[i].lon?.toDouble() ?? 0.0,
// // //               seg.trkpts[i + 1].lat?.toDouble() ?? 0.0,
// // //               seg.trkpts[i + 1].lon?.toDouble() ?? 0.0,
// // //             );
// // //             calculatedDistance += distance;
// // //           }
// // //         }
// // //       }
// // //
// // //       double finalDistance = calculatedDistance > memoryDistance ? calculatedDistance : memoryDistance;
// // //       totalDistance = finalDistance;
// // //
// // //       return finalDistance;
// // //     } catch (e) {
// // //       debugPrint('❌ Error calculating distance: $e');
// // //       return totalDistance;
// // //     }
// // //   }
// // //
// // //   int _getTotalPoints() {
// // //     int total = 0;
// // //     for (var seg in track.trksegs) {
// // //       total += seg.trkpts.length;
// // //     }
// // //     return total;
// // //   }
// // //
// // //   Future<void> init() async {
// // //     SharedPreferences pref = await SharedPreferences.getInstance();
// // //     await pref.reload();
// // //     userNameForLocation = pref.getString("userName") ?? "USERName";
// // //     userIdForLocation = pref.getString("userId") ?? "USERId";
// // //     nsmIdForLocation = pref.getString("userNSM") ?? "nsmUSER";
// // //     rsmIdForLocation = pref.getString("userRSM") ?? "rsmUSER";
// // //     smIdForLocation = pref.getString("userSM") ?? "smUSER";
// // //     dispatcherIdForLocation = pref.getString("userDISPATCHER") ?? "dispatcherUSER";
// // //     userCityForLocatiion = pref.getString("userCity") ?? "CITY";
// // //     userDesignationForLocation = pref.getString("userDesignation") ?? "DESIGNATION";
// // //   }
// // //
// // //   double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
// // //     double distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
// // //     return (distanceInMeters / 1000);
// // //   }
// // //
// // //   Future<void> deleteDocument() async {
// // //     try {
// // //       await FirebaseFirestore.instance
// // //           .collection('location')
// // //           .doc(userIdForLocation)
// // //           .delete();
// // //     } catch (e) {
// // //       debugPrint("❌ Error deleting document: $e");
// // //     }
// // //   }
// // //
// // //   Future<void> stopListening() async {
// // //     try {
// // //       positionStream?.cancel();
// // //       _forcedUpdateTimer?.cancel(); // ✅ Stop forced updates
// // //       _writeDebounceTimer?.cancel();
// // //
// // //       if (_pendingWrite) {
// // //         await _performFileWrite();
// // //       }
// // //
// // //       await calculateCurrentDistance();
// // //
// // //       SharedPreferences pref = await SharedPreferences.getInstance();
// // //       await pref.setDouble("TotalDistance", totalDistance);
// // //       await pref.setString("lastSessionEnd", DateTime.now().toIso8601String());
// // //
// // //       debugPrint("🛑 Stopped. Final: ${totalDistance.toStringAsFixed(3)} km | Points: ${_getTotalPoints()}");
// // //     } catch (e) {
// // //       debugPrint("❌ ERROR in stopListening: ${e.toString()}");
// // //     }
// // //   }
// // //
// // //   void resetDistance() {
// // //     totalDistance = 0.0;
// // //     debugPrint("🔄 Distance reset");
// // //   }
// // //
// // //   Map<String, dynamic> getServiceStatus() {
// // //     return {
// // //       'isInitialized': _isInitialized,
// // //       'isFirstLocationRecorded': _isFirstLocationRecorded,
// // //       'totalDistance': totalDistance,
// // //       'pointsRecorded': segment.trkpts.length,
// // //       'totalSegments': track.trksegs.length,
// // //       'totalAllPoints': _getTotalPoints(),
// // //       'lastTrackPoint': lastTrackPoint != null ?
// // //       '${lastTrackPoint!.latitude.toStringAsFixed(6)}, ${lastTrackPoint!.longitude.toStringAsFixed(6)}' : 'None',
// // //       'filePath': file.path,
// // //       'fileExists': file.existsSync(),
// // //       'fileSize': file.existsSync() ? file.lengthSync() : 0,
// // //       'pendingWrite': _pendingWrite,
// // //       'mode': 'ULTRA',
// // //       'accuracy': lastTrackPoint?.accuracy,
// // //     };
// // //   }
// // //
// // //   Future<String> getGpxContent() async {
// // //     try {
// // //       if (await file.exists()) {
// // //         return await file.readAsString();
// // //       }
// // //       return gpxString;
// // //     } catch (e) {
// // //       debugPrint("❌ Error reading GPX: $e");
// // //       return "";
// // //     }
// // //   }
// // //
// // //   Future<String> getConsolidatedGpx() async {
// // //     try {
// // //       Gpx consolidatedGpx = Gpx();
// // //       Trk consolidatedTrack = Trk();
// // //       consolidatedTrack.name = "Ultra Track ${DateFormat('dd-MM-yyyy').format(DateTime.now())}";
// // //
// // //       for (var seg in track.trksegs) {
// // //         if (seg.trkpts.isNotEmpty) {
// // //           consolidatedTrack.trksegs.add(seg);
// // //         }
// // //       }
// // //
// // //       consolidatedGpx.trks.add(consolidatedTrack);
// // //       return GpxWriter().asString(consolidatedGpx, pretty: true);
// // //     } catch (e) {
// // //       debugPrint("❌ Error consolidating GPX: $e");
// // //       return gpxString;
// // //     }
// // //   }
// // //
// // //   Future<void> saveGpxFile(String filePath) async {
// // //     try {
// // //       File outputFile = File(filePath);
// // //       String content = await getConsolidatedGpx();
// // //       await outputFile.writeAsString(content, flush: true);
// // //       debugPrint("💾 GPX saved: $filePath");
// // //     } catch (e) {
// // //       debugPrint("❌ Error saving GPX: $e");
// // //     }
// // //   }
// // // }
// //
// // ///remove forebase
// //
// // import 'dart:async';
// // import 'dart:io';
// // import 'package:flutter/foundation.dart';
// // import 'package:geolocator/geolocator.dart';
// // import 'package:gpx/gpx.dart';
// // import 'package:intl/intl.dart';
// // import 'package:path_provider/path_provider.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'package:synchronized/synchronized.dart';
// //
// // class LocationService {
// //   late Gpx gpx;
// //   late Trk track;
// //   late Trkseg segment;
// //   late File file;
// //   late bool isFirstRun;
// //   late bool isConnected;
// //   late var lat, longi;
// //   late String userIdForLocation;
// //   late String userCityForLocatiion;
// //   late String userDesignationForLocation;
// //   late String userNameForLocation;
// //   late String rsmIdForLocation;
// //   late String nsmIdForLocation;
// //   late String smIdForLocation;
// //   late String dispatcherIdForLocation;
// //   late final Directory? downloadDirectory;
// //   late double totalDistance;
// //   Position? lastTrackPoint;
// //   String gpxString = "";
// //
// //   bool _isInitialized = false;
// //   bool _isFirstLocationRecorded = false;
// //   Completer<void>? _initializationCompleter;
// //   List<Trkseg> _segments = [];
// //   final Lock _fileWriteLock = Lock();
// //   Timer? _writeDebounceTimer;
// //   Timer? _forcedUpdateTimer;
// //   static const Duration _writeDebounceDelay = Duration(seconds: 1);
// //   bool _pendingWrite = false;
// //
// //   static const double _minDistanceFilter = 1.0;
// //   static const int _maxTimeBetweenPoints = 5;
// //   static const double _maxAcceptableAccuracy = 20.0;
// //   static const double _maxSpeedThreshold = 60.0;
// //
// //   DateTime? _lastPointTime;
// //   int _consecutiveLowAccuracy = 0;
// //
// //   LocationSettings? _locationSettings;
// //
// //   LocationService() {
// //     totalDistance = 0.0;
// //     lastTrackPoint = null;
// //     _isInitialized = false;
// //     _isFirstLocationRecorded = false;
// //     _segments = [];
// //     init();
// //     lat = 0.0;
// //     longi = 0.0;
// //     isConnected = false;
// //   }
// //
// //   StreamSubscription<Position>? positionStream;
// //
// //   Future<void> _configureLocationSettings() async {
// //     _locationSettings = AndroidSettings(
// //       accuracy: LocationAccuracy.bestForNavigation,
// //       distanceFilter: 1,
// //       forceLocationManager: true,
// //       intervalDuration: const Duration(seconds: 1),
// //     );
// //   }
// //
// //   Future<void> listenLocation() async {
// //     if (!_isInitialized) {
// //       await _initializeService();
// //     }
// //
// //     _startForcedUpdateTimer();
// //
// //     positionStream = Geolocator.getPositionStream(locationSettings: _locationSettings!)
// //         .listen((Position position) async {
// //       await _handleLocationUpdate(position);
// //     }, onError: (error) {
// //       debugPrint("❌ Location stream error: $error");
// //     });
// //   }
// //
// //   void _startForcedUpdateTimer() {
// //     _forcedUpdateTimer?.cancel();
// //     _forcedUpdateTimer = Timer.periodic(
// //       const Duration(seconds: _maxTimeBetweenPoints),
// //           (timer) async {
// //         if (lastTrackPoint != null && _lastPointTime != null) {
// //           int secondsSinceLast = DateTime.now().difference(_lastPointTime!).inSeconds;
// //           if (secondsSinceLast >= _maxTimeBetweenPoints) {
// //             await _insertForcedPoint();
// //           }
// //         }
// //       },
// //     );
// //   }
// //
// //   Future<void> _insertForcedPoint() async {
// //     if (lastTrackPoint == null) return;
// //
// //     final forcedPoint = Wpt(
// //       lat: lastTrackPoint!.latitude,
// //       lon: lastTrackPoint!.longitude,
// //       time: DateTime.now(),
// //       name: 'forced',
// //     );
// //
// //     segment.trkpts.add(forcedPoint);
// //     _lastPointTime = DateTime.now();
// //
// //     debugPrint("⏰ Forced point inserted at ${segment.trkpts.length} total points");
// //     _debouncedUpdateGpxFile();
// //   }
// //
// //   Future<void> checkAndStartNewSegment() async {
// //     SharedPreferences prefs = await SharedPreferences.getInstance();
// //     String? lastClockOutTimeString = prefs.getString('lastClockOutTime');
// //     String? currentSessionStartString = prefs.getString('currentSessionStart');
// //
// //     if (lastClockOutTimeString != null && currentSessionStartString != null) {
// //       DateTime lastClockOutTime = DateTime.parse(lastClockOutTimeString);
// //       DateTime currentSessionStart = DateTime.parse(currentSessionStartString);
// //
// //       if (currentSessionStart.difference(lastClockOutTime).inMinutes > 30) {
// //         await _startNewSegment();
// //         debugPrint("🔄 Starting new GPX segment");
// //       }
// //     }
// //   }
// //
// //   Future<void> _startNewSegment() async {
// //     try {
// //       if (segment.trkpts.isNotEmpty) {
// //         _segments.add(segment);
// //       }
// //
// //       segment = Trkseg();
// //       lastTrackPoint = null;
// //
// //       if (track.trksegs.isEmpty) {
// //         track.trksegs = [segment];
// //       } else {
// //         track.trksegs.add(segment);
// //       }
// //
// //       debugPrint("🔄 Started new GPX segment #${track.trksegs.length}");
// //     } catch (e) {
// //       debugPrint("❌ Error starting new segment: $e");
// //     }
// //   }
// //
// //   Future<void> _initializeService() async {
// //     if (_initializationCompleter != null) {
// //       return _initializationCompleter!.future;
// //     }
// //
// //     _initializationCompleter = Completer<void>();
// //
// //     try {
// //       debugPrint("🔄 Initializing Ultra Location Service...");
// //       await _configureLocationSettings();
// //       await _loadUserData();
// //       await checkAndStartNewSegment();
// //       await _initializeGpxFile();
// //       await _waitForFirstValidLocation();
// //
// //       _isInitialized = true;
// //       _initializationCompleter!.complete();
// //       debugPrint("✅ Ultra Location Service Initialized - Raw GPS Mode");
// //     } catch (e) {
// //       debugPrint("❌ Initialization Failed: $e");
// //       _initializationCompleter!.completeError(e);
// //     }
// //   }
// //
// //   Future<void> _waitForFirstValidLocation() async {
// //     try {
// //       debugPrint("📍 Acquiring ultra-precise initial fix...");
// //
// //       Position? initialPosition;
// //       int attempts = 0;
// //       const maxAttempts = 30;
// //
// //       while (attempts < maxAttempts && initialPosition == null) {
// //         try {
// //           initialPosition = await Geolocator.getCurrentPosition(
// //             desiredAccuracy: LocationAccuracy.bestForNavigation,
// //             timeLimit: const Duration(seconds: 2),
// //           );
// //
// //           if (initialPosition.accuracy > _maxAcceptableAccuracy) {
// //             debugPrint("⚠️ Initial fix accuracy ${initialPosition.accuracy}m, retrying...");
// //             initialPosition = null;
// //             await Future.delayed(const Duration(seconds: 1));
// //           }
// //         } catch (e) {
// //           // Timeout or error, retry
// //         }
// //         attempts++;
// //       }
// //
// //       if (initialPosition == null) {
// //         initialPosition = await Geolocator.getCurrentPosition(
// //           desiredAccuracy: LocationAccuracy.high,
// //         );
// //       }
// //
// //       lat = initialPosition.latitude.toString();
// //       longi = initialPosition.longitude.toString();
// //
// //       lastTrackPoint = Position(
// //         latitude: initialPosition.latitude,
// //         longitude: initialPosition.longitude,
// //         accuracy: initialPosition.accuracy,
// //         altitude: initialPosition.altitude,
// //         altitudeAccuracy: initialPosition.altitudeAccuracy ?? 0,
// //         heading: initialPosition.heading,
// //         headingAccuracy: initialPosition.headingAccuracy ?? 0,
// //         speed: initialPosition.speed,
// //         speedAccuracy: initialPosition.speedAccuracy ?? 0,
// //         timestamp: initialPosition.timestamp,
// //       );
// //
// //       _isFirstLocationRecorded = true;
// //       _lastPointTime = DateTime.now();
// //       debugPrint("🎯 Ultra-precise initial fix: ${initialPosition.accuracy}m accuracy");
// //     } catch (e) {
// //       debugPrint("⚠️ Could not get initial position: $e");
// //       lastTrackPoint = null;
// //     }
// //   }
// //
// //   Future<void> _loadUserData() async {
// //     SharedPreferences pref = await SharedPreferences.getInstance();
// //     await pref.reload();
// //
// //     userNameForLocation = pref.getString("userName") ?? "USERName";
// //     userIdForLocation = pref.getString("userId") ?? "USERId";
// //     nsmIdForLocation = pref.getString("userNSM") ?? "nsmUSER";
// //     rsmIdForLocation = pref.getString("userRSM") ?? "rsmUSER";
// //     smIdForLocation = pref.getString("userSM") ?? "smUSER";
// //     dispatcherIdForLocation = pref.getString("userDISPATCHER") ?? "dispatcherUSER";
// //     userCityForLocatiion = pref.getString("userCity") ?? "CITY";
// //     userDesignationForLocation = pref.getString("userDesignation") ?? "DESIGNATION";
// //   }
// //
// //   Future<void> _initializeGpxFile() async {
// //     try {
// //       gpx = Gpx();
// //       track = Trk();
// //       segment = Trkseg();
// //       _segments = [];
// //
// //       final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
// //       downloadDirectory = await getDownloadsDirectory();
// //
// //       final filePath = "${downloadDirectory!.path}/track_${userIdForLocation}_$date.gpx";
// //       file = File(filePath);
// //
// //       if (await file.exists()) {
// //         String existingContent = await file.readAsString();
// //         if (existingContent.trim().isNotEmpty) {
// //           try {
// //             Gpx existingGpx = GpxReader().fromString(existingContent);
// //             if (existingGpx.trks.isNotEmpty) {
// //               gpx.trks = existingGpx.trks;
// //               track = gpx.trks[0];
// //
// //               if (track.trksegs.isNotEmpty) {
// //                 _segments = List<Trkseg>.from(track.trksegs);
// //                 segment = track.trksegs.last;
// //               } else {
// //                 track.trksegs.add(segment);
// //               }
// //
// //               isFirstRun = false;
// //               totalDistance = await _calculateDistanceFromExistingFile();
// //               debugPrint("📂 Existing GPX loaded: ${totalDistance.toStringAsFixed(3)} km, ${_getTotalPoints()} points");
// //             } else {
// //               _createNewGpxStructure();
// //             }
// //           } catch (e) {
// //             debugPrint("⚠️ Corrupted GPX file, creating new: $e");
// //             _createNewGpxStructure();
// //           }
// //         } else {
// //           _createNewGpxStructure();
// //         }
// //       } else {
// //         _createNewGpxStructure();
// //       }
// //     } catch (e) {
// //       debugPrint('❌ Error initializing GPX file: $e');
// //       _createNewGpxStructure();
// //     }
// //   }
// //
// //   Future<double> _calculateDistanceFromExistingFile() async {
// //     try {
// //       if (!await file.exists()) return 0.0;
// //       String gpxContent = await file.readAsString();
// //       if (gpxContent.isEmpty) return 0.0;
// //
// //       Gpx existingGpx = GpxReader().fromString(gpxContent);
// //       double existingDistance = 0.0;
// //
// //       for (var trk in existingGpx.trks) {
// //         for (var seg in trk.trksegs) {
// //           if (seg.trkpts.length < 2) continue;
// //           for (int i = 0; i < seg.trkpts.length - 1; i++) {
// //             double distance = calculateDistance(
// //               seg.trkpts[i].lat?.toDouble() ?? 0.0,
// //               seg.trkpts[i].lon?.toDouble() ?? 0.0,
// //               seg.trkpts[i + 1].lat?.toDouble() ?? 0.0,
// //               seg.trkpts[i + 1].lon?.toDouble() ?? 0.0,
// //             );
// //             existingDistance += distance;
// //           }
// //         }
// //       }
// //       return existingDistance;
// //     } catch (e) {
// //       debugPrint("❌ Error calculating existing distance: $e");
// //       return 0.0;
// //     }
// //   }
// //
// //   void _createNewGpxStructure() {
// //     gpx = Gpx();
// //     track = Trk();
// //     segment = Trkseg();
// //     _segments = [];
// //
// //     track.trksegs.add(segment);
// //     gpx.trks.add(track);
// //
// //     isFirstRun = true;
// //     file.createSync(recursive: true);
// //     totalDistance = 0.0;
// //     debugPrint("📁 Created new ultra-precision GPX file");
// //   }
// //
// //   Future<void> _handleLocationUpdate(Position position) async {
// //     if (position.accuracy > _maxAcceptableAccuracy) {
// //       _consecutiveLowAccuracy++;
// //       if (_consecutiveLowAccuracy > 5) {
// //         debugPrint("⚠️ Too many low accuracy readings (${position.accuracy}m), accepting anyway");
// //       } else {
// //         debugPrint("⚠️ Low accuracy: ${position.accuracy}m, skipping (${_consecutiveLowAccuracy}/5)");
// //         return;
// //       }
// //     } else {
// //       _consecutiveLowAccuracy = 0;
// //     }
// //
// //     if (position.speed > _maxSpeedThreshold) {
// //       debugPrint("⚠️ Impossible speed: ${(position.speed * 3.6).toStringAsFixed(1)} km/h");
// //       return;
// //     }
// //
// //     lat = position.latitude.toString();
// //     longi = position.longitude.toString();
// //
// //     final trackPoint = Wpt(
// //       lat: position.latitude,
// //       lon: position.longitude,
// //       time: DateTime.now(),
// //       ele: position.altitude,
// //       name: position.speed > 0.5 ? 'moving' : 'stationary',
// //     );
// //
// //     bool shouldAddPoint = false;
// //     double segmentDistance = 0.0;
// //     int secondsSinceLastPoint = _lastPointTime != null
// //         ? DateTime.now().difference(_lastPointTime!).inSeconds
// //         : 999;
// //
// //     if (lastTrackPoint != null) {
// //       segmentDistance = calculateDistance(
// //         lastTrackPoint!.latitude,
// //         lastTrackPoint!.longitude,
// //         position.latitude,
// //         position.longitude,
// //       );
// //
// //       if (segmentDistance >= _minDistanceFilter || secondsSinceLastPoint >= _maxTimeBetweenPoints) {
// //         shouldAddPoint = true;
// //
// //         if (segmentDistance >= _minDistanceFilter) {
// //           totalDistance += segmentDistance;
// //         }
// //
// //         debugPrint("📍 ${secondsSinceLastPoint >= _maxTimeBetweenPoints ? '⏰ TIME' : '📏 DIST'} | "
// //             "Moved: ${(segmentDistance * 1000).toStringAsFixed(1)}m | "
// //             "Time: ${secondsSinceLastPoint}s | "
// //             "Acc: ${position.accuracy.toStringAsFixed(1)}m | "
// //             "Total: ${totalDistance.toStringAsFixed(3)} km | "
// //             "Points: ${_getTotalPoints()}");
// //       }
// //     } else {
// //       shouldAddPoint = true;
// //       debugPrint("🎯 First ultra-precise point added (${position.accuracy}m accuracy)");
// //     }
// //
// //     if (shouldAddPoint) {
// //       segment.trkpts.add(trackPoint);
// //       _lastPointTime = DateTime.now();
// //
// //       if (segment.trkpts.length > 5000) {
// //         await _startNewSegment();
// //       }
// //
// //       _debouncedUpdateGpxFile();
// //     }
// //
// //     lastTrackPoint = Position(
// //       latitude: position.latitude,
// //       longitude: position.longitude,
// //       accuracy: position.accuracy,
// //       altitude: position.altitude,
// //       altitudeAccuracy: position.altitudeAccuracy ?? 0,
// //       heading: position.heading,
// //       headingAccuracy: position.headingAccuracy ?? 0,
// //       speed: position.speed,
// //       speedAccuracy: position.speedAccuracy ?? 0,
// //       timestamp: position.timestamp,
// //     );
// //   }
// //
// //   void _debouncedUpdateGpxFile() {
// //     _pendingWrite = true;
// //     _writeDebounceTimer?.cancel();
// //     _writeDebounceTimer = Timer(_writeDebounceDelay, () {
// //       _performFileWrite();
// //     });
// //   }
// //
// //   Future<void> _performFileWrite() async {
// //     if (!_pendingWrite) return;
// //
// //     await _fileWriteLock.synchronized(() async {
// //       try {
// //         if (_segments.isNotEmpty) {
// //           track.trksegs = List<Trkseg>.from(_segments);
// //           if (!track.trksegs.contains(segment)) {
// //             track.trksegs.add(segment);
// //           }
// //         }
// //
// //         gpxString = GpxWriter().asString(gpx, pretty: true);
// //         await file.writeAsString(gpxString, flush: true);
// //         _pendingWrite = false;
// //
// //         debugPrint("💾 GPX Saved: ${track.trksegs.length} segments, ${_getTotalPoints()} points, "
// //             "${(await file.length() / 1024).toStringAsFixed(1)} KB");
// //       } catch (e) {
// //         debugPrint('❌ Error writing GPX: $e');
// //       }
// //     });
// //   }
// //
// //   double getCurrentDistance() {
// //     return double.parse(totalDistance.toStringAsFixed(3));
// //   }
// //
// //   Future<double> calculateCurrentDistance() async {
// //     try {
// //       double memoryDistance = totalDistance;
// //
// //       if (!await file.exists()) return memoryDistance;
// //
// //       String gpxContent = await file.readAsString();
// //       if (gpxContent.isEmpty) return memoryDistance;
// //
// //       Gpx gpx = GpxReader().fromString(gpxContent);
// //       double calculatedDistance = 0.0;
// //
// //       for (var trk in gpx.trks) {
// //         for (var seg in trk.trksegs) {
// //           if (seg.trkpts.length < 2) continue;
// //           for (int i = 0; i < seg.trkpts.length - 1; i++) {
// //             double distance = calculateDistance(
// //               seg.trkpts[i].lat?.toDouble() ?? 0.0,
// //               seg.trkpts[i].lon?.toDouble() ?? 0.0,
// //               seg.trkpts[i + 1].lat?.toDouble() ?? 0.0,
// //               seg.trkpts[i + 1].lon?.toDouble() ?? 0.0,
// //             );
// //             calculatedDistance += distance;
// //           }
// //         }
// //       }
// //
// //       double finalDistance = calculatedDistance > memoryDistance ? calculatedDistance : memoryDistance;
// //       totalDistance = finalDistance;
// //
// //       return finalDistance;
// //     } catch (e) {
// //       debugPrint('❌ Error calculating distance: $e');
// //       return totalDistance;
// //     }
// //   }
// //
// //   int _getTotalPoints() {
// //     int total = 0;
// //     for (var seg in track.trksegs) {
// //       total += seg.trkpts.length;
// //     }
// //     return total;
// //   }
// //
// //   Future<void> init() async {
// //     SharedPreferences pref = await SharedPreferences.getInstance();
// //     await pref.reload();
// //     userNameForLocation = pref.getString("userName") ?? "USERName";
// //     userIdForLocation = pref.getString("userId") ?? "USERId";
// //     nsmIdForLocation = pref.getString("userNSM") ?? "nsmUSER";
// //     rsmIdForLocation = pref.getString("userRSM") ?? "rsmUSER";
// //     smIdForLocation = pref.getString("userSM") ?? "smUSER";
// //     dispatcherIdForLocation = pref.getString("userDISPATCHER") ?? "dispatcherUSER";
// //     userCityForLocatiion = pref.getString("userCity") ?? "CITY";
// //     userDesignationForLocation = pref.getString("userDesignation") ?? "DESIGNATION";
// //   }
// //
// //   double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
// //     double distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
// //     return (distanceInMeters / 1000);
// //   }
// //
// //   Future<void> stopListening() async {
// //     try {
// //       positionStream?.cancel();
// //       _forcedUpdateTimer?.cancel();
// //       _writeDebounceTimer?.cancel();
// //
// //       if (_pendingWrite) {
// //         await _performFileWrite();
// //       }
// //
// //       await calculateCurrentDistance();
// //
// //       SharedPreferences pref = await SharedPreferences.getInstance();
// //       await pref.setDouble("TotalDistance", totalDistance);
// //       await pref.setString("lastSessionEnd", DateTime.now().toIso8601String());
// //
// //       debugPrint("🛑 Stopped. Final: ${totalDistance.toStringAsFixed(3)} km | Points: ${_getTotalPoints()}");
// //     } catch (e) {
// //       debugPrint("❌ ERROR in stopListening: ${e.toString()}");
// //     }
// //   }
// //
// //   void resetDistance() {
// //     totalDistance = 0.0;
// //     debugPrint("🔄 Distance reset");
// //   }
// //
// //   Map<String, dynamic> getServiceStatus() {
// //     return {
// //       'isInitialized': _isInitialized,
// //       'isFirstLocationRecorded': _isFirstLocationRecorded,
// //       'totalDistance': totalDistance,
// //       'pointsRecorded': segment.trkpts.length,
// //       'totalSegments': track.trksegs.length,
// //       'totalAllPoints': _getTotalPoints(),
// //       'lastTrackPoint': lastTrackPoint != null ?
// //       '${lastTrackPoint!.latitude.toStringAsFixed(6)}, ${lastTrackPoint!.longitude.toStringAsFixed(6)}' : 'None',
// //       'filePath': file.path,
// //       'fileExists': file.existsSync(),
// //       'fileSize': file.existsSync() ? file.lengthSync() : 0,
// //       'pendingWrite': _pendingWrite,
// //       'mode': 'ULTRA',
// //       'accuracy': lastTrackPoint?.accuracy,
// //     };
// //   }
// //
// //   Future<String> getGpxContent() async {
// //     try {
// //       if (await file.exists()) {
// //         return await file.readAsString();
// //       }
// //       return gpxString;
// //     } catch (e) {
// //       debugPrint("❌ Error reading GPX: $e");
// //       return "";
// //     }
// //   }
// //
// //   Future<String> getConsolidatedGpx() async {
// //     try {
// //       Gpx consolidatedGpx = Gpx();
// //       Trk consolidatedTrack = Trk();
// //       consolidatedTrack.name = "Ultra Track ${DateFormat('dd-MM-yyyy').format(DateTime.now())}";
// //
// //       for (var seg in track.trksegs) {
// //         if (seg.trkpts.isNotEmpty) {
// //           consolidatedTrack.trksegs.add(seg);
// //         }
// //       }
// //
// //       consolidatedGpx.trks.add(consolidatedTrack);
// //       return GpxWriter().asString(consolidatedGpx, pretty: true);
// //     } catch (e) {
// //       debugPrint("❌ Error consolidating GPX: $e");
// //       return gpxString;
// //     }
// //   }
// //
// //   Future<void> saveGpxFile(String filePath) async {
// //     try {
// //       File outputFile = File(filePath);
// //       String content = await getConsolidatedGpx();
// //       await outputFile.writeAsString(content, flush: true);
// //       debugPrint("💾 GPX saved: $filePath");
// //     } catch (e) {
// //       debugPrint("❌ Error saving GPX: $e");
// //     }
// //   }
// // }
//
// import 'dart:async';
// import 'dart:io';
// import 'dart:math';
// import 'package:flutter/foundation.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:gpx/gpx.dart';
// import 'package:intl/intl.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:synchronized/synchronized.dart';
//
// // ─────────────────────────────────────────────────────────────────────────────
// // GPS Kalman Filter — eliminates jumps by blending noisy readings over time
// // ─────────────────────────────────────────────────────────────────────────────
// class GpsKalmanFilter {
//   double _lat = 0;
//   double _lon = 0;
//   double _variance = -1; // negative = uninitialized
//
//   static const double _minAccuracy = 1.0;
//
//   bool get isInitialized => _variance >= 0;
//
//   void init(double lat, double lon, double accuracy) {
//     _lat = lat;
//     _lon = lon;
//     _variance = accuracy * accuracy;
//   }
//
//   /// Returns smoothed [lat, lon] given a new GPS reading.
//   List<double> process(double lat, double lon, double accuracy, int timestampMs) {
//     if (!isInitialized) {
//       init(lat, lon, accuracy);
//       return [lat, lon];
//     }
//
//     final accSq = max(accuracy, _minAccuracy) * max(accuracy, _minAccuracy);
//
//     // Time-based process noise: more time = more uncertainty
//     // 3 m/s² assumed movement noise
//     const processNoise = 3.0;
//     _variance += processNoise * processNoise;
//
//     // Kalman gain
//     final k = _variance / (_variance + accSq);
//
//     // Correction
//     _lat += k * (lat - _lat);
//     _lon += k * (lon - _lon);
//     _variance = (1 - k) * _variance;
//
//     return [_lat, _lon];
//   }
//
//   void reset() {
//     _variance = -1;
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Outlier Detector — rejects impossible jumps
// // ─────────────────────────────────────────────────────────────────────────────
// class GpsOutlierDetector {
//   static const double _maxReasonableSpeedMs = 14.0; // 50 km/h
//   static const double _jumpThresholdMeters = 100.0; // >100m in <2s = jump
//
//   double? _lastLat;
//   double? _lastLon;
//   DateTime? _lastTime;
//   int _rejectedCount = 0;
//
//   /// Returns true if this point looks like a real location (not a jump).
//   bool isValid(double lat, double lon, double accuracy, DateTime time) {
//     // Reject very inaccurate readings
//     if (accuracy > 50.0) {
//       debugPrint("🚫 Rejected: accuracy ${accuracy.toStringAsFixed(1)}m too low");
//       return false;
//     }
//
//     if (_lastLat == null || _lastLon == null || _lastTime == null) {
//       _update(lat, lon, time);
//       return true;
//     }
//
//     final distanceM = Geolocator.distanceBetween(_lastLat!, _lastLon!, lat, lon);
//     final elapsedSec = time.difference(_lastTime!).inMilliseconds / 1000.0;
//
//     if (elapsedSec < 0.1) return false; // duplicate reading
//
//     final speedMs = distanceM / elapsedSec;
//
//     // Reject if speed is physically impossible
//     if (speedMs > _maxReasonableSpeedMs) {
//       _rejectedCount++;
//       debugPrint("🚫 Rejected jump: ${distanceM.toStringAsFixed(1)}m in "
//           "${elapsedSec.toStringAsFixed(1)}s = ${(speedMs * 3.6).toStringAsFixed(1)} km/h "
//           "(rejected $_rejectedCount)");
//
//       // After 3 consecutive rejects, accept anyway (GPS recovered to new position)
//       if (_rejectedCount >= 3) {
//         debugPrint("⚠️ 3 consecutive rejects — accepting new position as valid");
//         _rejectedCount = 0;
//         _update(lat, lon, time);
//         return true;
//       }
//       return false;
//     }
//
//     _rejectedCount = 0;
//     _update(lat, lon, time);
//     return true;
//   }
//
//   void _update(double lat, double lon, DateTime time) {
//     _lastLat = lat;
//     _lastLon = lon;
//     _lastTime = time;
//   }
//
//   void reset() {
//     _lastLat = null;
//     _lastLon = null;
//     _lastTime = null;
//     _rejectedCount = 0;
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // LocationService
// // ─────────────────────────────────────────────────────────────────────────────
// class LocationService {
//   late Gpx gpx;
//   late Trk track;
//   late Trkseg segment;
//   late File file;
//   late bool isFirstRun;
//   late bool isConnected;
//   late var lat, longi;
//   late String userIdForLocation;
//   late String userCityForLocatiion;
//   late String userDesignationForLocation;
//   late String userNameForLocation;
//   late String rsmIdForLocation;
//   late String nsmIdForLocation;
//   late String smIdForLocation;
//   late String dispatcherIdForLocation;
//   late final Directory? downloadDirectory;
//   late double totalDistance;
//   Position? lastTrackPoint;
//   String gpxString = "";
//
//   bool _isInitialized = false;
//   bool _isFirstLocationRecorded = false;
//   Completer<void>? _initializationCompleter;
//   List<Trkseg> _segments = [];
//   final Lock _fileWriteLock = Lock();
//   Timer? _writeDebounceTimer;
//   Timer? _forcedUpdateTimer;
//   static const Duration _writeDebounceDelay = Duration(seconds: 2);
//   bool _pendingWrite = false;
//
//   // ── Thresholds ──────────────────────────────────────────────────────────────
//   static const double _minDistanceFilter = 3.0;   // metres — ignore micro-jitter
//   static const int _maxTimeBetweenPoints = 10;    // seconds
//   static const double _maxAcceptableAccuracy = 40.0;
//   static const int _forcedPointIntervalSec = 30;  // only add forced point every 30s
//
//   DateTime? _lastPointTime;
//   int _consecutiveLowAccuracy = 0;
//
//   // ── Anti-jump helpers ───────────────────────────────────────────────────────
//   final GpsKalmanFilter _kalman = GpsKalmanFilter();
//   final GpsOutlierDetector _outlierDetector = GpsOutlierDetector();
//
//   LocationSettings? _locationSettings;
//
//   LocationService() {
//     totalDistance = 0.0;
//     lastTrackPoint = null;
//     _isInitialized = false;
//     _isFirstLocationRecorded = false;
//     _segments = [];
//     init();
//     lat = 0.0;
//     longi = 0.0;
//     isConnected = false;
//   }
//
//   StreamSubscription<Position>? positionStream;
//
//   Future<void> _configureLocationSettings() async {
//     _locationSettings = AndroidSettings(
//       accuracy: LocationAccuracy.high,           // bestForNavigation causes more jitter
//       distanceFilter: 2,                         // OS-level pre-filter: ignore <2m moves
//       forceLocationManager: false,                // prefer fused provider (smoother)
//       intervalDuration: const Duration(seconds: 2),
//     );
//   }
//
//   Future<void> listenLocation() async {
//     if (!_isInitialized) {
//       await _initializeService();
//     }
//     _startForcedUpdateTimer();
//     positionStream = Geolocator.getPositionStream(
//       locationSettings: _locationSettings!,
//     ).listen((Position position) async {
//       await _handleLocationUpdate(position);
//     }, onError: (error) {
//       debugPrint("❌ Location stream error: $error");
//     });
//   }
//
//   void _startForcedUpdateTimer() {
//     _forcedUpdateTimer?.cancel();
//     _forcedUpdateTimer = Timer.periodic(
//       const Duration(seconds: _forcedPointIntervalSec),
//           (timer) async {
//         if (lastTrackPoint != null && _lastPointTime != null) {
//           int secondsSinceLast =
//               DateTime.now().difference(_lastPointTime!).inSeconds;
//           if (secondsSinceLast >= _forcedPointIntervalSec) {
//             await _insertForcedPoint();
//           }
//         }
//       },
//     );
//   }
//
//   Future<void> _insertForcedPoint() async {
//     if (lastTrackPoint == null) return;
//
//     // Use Kalman-smoothed position, not raw lastTrackPoint
//     final forcedPoint = Wpt(
//       lat: _kalman.isInitialized
//           ? _kalman.process(
//         lastTrackPoint!.latitude,
//         lastTrackPoint!.longitude,
//         lastTrackPoint!.accuracy,
//         DateTime.now().millisecondsSinceEpoch,
//       )[0]
//           : lastTrackPoint!.latitude,
//       lon: _kalman.isInitialized
//           ? _kalman.process(
//         lastTrackPoint!.latitude,
//         lastTrackPoint!.longitude,
//         lastTrackPoint!.accuracy,
//         DateTime.now().millisecondsSinceEpoch,
//       )[1]
//           : lastTrackPoint!.longitude,
//       time: DateTime.now(),
//       name: 'stationary',
//     );
//
//     segment.trkpts.add(forcedPoint);
//     _lastPointTime = DateTime.now();
//     debugPrint("⏰ Forced stationary point — total: ${segment.trkpts.length}");
//     _debouncedUpdateGpxFile();
//   }
//
//   Future<void> checkAndStartNewSegment() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? lastClockOutTimeString = prefs.getString('lastClockOutTime');
//     String? currentSessionStartString = prefs.getString('currentSessionStart');
//
//     if (lastClockOutTimeString != null && currentSessionStartString != null) {
//       DateTime lastClockOutTime = DateTime.parse(lastClockOutTimeString);
//       DateTime currentSessionStart = DateTime.parse(currentSessionStartString);
//
//       if (currentSessionStart.difference(lastClockOutTime).inMinutes > 30) {
//         await _startNewSegment();
//         // Reset filters for new segment
//         _kalman.reset();
//         _outlierDetector.reset();
//         debugPrint("🔄 New GPX segment + filters reset");
//       }
//     }
//   }
//
//   Future<void> _startNewSegment() async {
//     try {
//       if (segment.trkpts.isNotEmpty) {
//         _segments.add(segment);
//       }
//       segment = Trkseg();
//       lastTrackPoint = null;
//
//       if (track.trksegs.isEmpty) {
//         track.trksegs = [segment];
//       } else {
//         track.trksegs.add(segment);
//       }
//       debugPrint("🔄 New GPX segment #${track.trksegs.length}");
//     } catch (e) {
//       debugPrint("❌ Error starting new segment: $e");
//     }
//   }
//
//   Future<void> _initializeService() async {
//     if (_initializationCompleter != null) {
//       return _initializationCompleter!.future;
//     }
//     _initializationCompleter = Completer<void>();
//     try {
//       debugPrint("🔄 Initializing Location Service (Anti-Jump Mode)…");
//       await _configureLocationSettings();
//       await _loadUserData();
//       await checkAndStartNewSegment();
//       await _initializeGpxFile();
//       await _waitForFirstValidLocation();
//       _isInitialized = true;
//       _initializationCompleter!.complete();
//       debugPrint("✅ Location Service ready — Kalman + Outlier Rejection active");
//     } catch (e) {
//       debugPrint("❌ Init failed: $e");
//       _initializationCompleter!.completeError(e);
//     }
//   }
//
//   Future<void> _waitForFirstValidLocation() async {
//     try {
//       debugPrint("📍 Acquiring initial position…");
//       Position? initialPosition;
//       int attempts = 0;
//
//       while (attempts < 20 && initialPosition == null) {
//         try {
//           final pos = await Geolocator.getCurrentPosition(
//             desiredAccuracy: LocationAccuracy.high,
//             timeLimit: const Duration(seconds: 3),
//           );
//           if (pos.accuracy <= _maxAcceptableAccuracy) {
//             initialPosition = pos;
//           } else {
//             debugPrint("⚠️ Accuracy ${pos.accuracy.toStringAsFixed(1)}m, retrying…");
//             await Future.delayed(const Duration(seconds: 1));
//           }
//         } catch (_) {}
//         attempts++;
//       }
//
//       initialPosition ??= await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.medium,
//       );
//
//       // Seed the Kalman filter with the first known-good position
//       _kalman.init(
//         initialPosition.latitude,
//         initialPosition.longitude,
//         initialPosition.accuracy,
//       );
//       _outlierDetector.reset();
//
//       lat = initialPosition.latitude.toString();
//       longi = initialPosition.longitude.toString();
//       lastTrackPoint = initialPosition;
//       _isFirstLocationRecorded = true;
//       _lastPointTime = DateTime.now();
//
//       debugPrint(
//           "🎯 Initial fix: ${initialPosition.accuracy.toStringAsFixed(1)}m accuracy");
//     } catch (e) {
//       debugPrint("⚠️ Could not get initial position: $e");
//       lastTrackPoint = null;
//     }
//   }
//
//   Future<void> _loadUserData() async {
//     SharedPreferences pref = await SharedPreferences.getInstance();
//     await pref.reload();
//     userNameForLocation = pref.getString("userName") ?? "USERName";
//     userIdForLocation = pref.getString("userId") ?? "USERId";
//     nsmIdForLocation = pref.getString("userNSM") ?? "nsmUSER";
//     rsmIdForLocation = pref.getString("userRSM") ?? "rsmUSER";
//     smIdForLocation = pref.getString("userSM") ?? "smUSER";
//     dispatcherIdForLocation =
//         pref.getString("userDISPATCHER") ?? "dispatcherUSER";
//     userCityForLocatiion = pref.getString("userCity") ?? "CITY";
//     userDesignationForLocation =
//         pref.getString("userDesignation") ?? "DESIGNATION";
//   }
//
//   Future<void> _initializeGpxFile() async {
//     try {
//       gpx = Gpx();
//       track = Trk();
//       segment = Trkseg();
//       _segments = [];
//
//       final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
//       downloadDirectory = await getDownloadsDirectory();
//       final filePath =
//           "${downloadDirectory!.path}/track_${userIdForLocation}_$date.gpx";
//       file = File(filePath);
//
//       if (await file.exists()) {
//         String existingContent = await file.readAsString();
//         if (existingContent.trim().isNotEmpty) {
//           try {
//             Gpx existingGpx = GpxReader().fromString(existingContent);
//             if (existingGpx.trks.isNotEmpty) {
//               gpx.trks = existingGpx.trks;
//               track = gpx.trks[0];
//               if (track.trksegs.isNotEmpty) {
//                 _segments = List<Trkseg>.from(track.trksegs);
//                 segment = track.trksegs.last;
//               } else {
//                 track.trksegs.add(segment);
//               }
//               isFirstRun = false;
//               totalDistance = await _calculateDistanceFromExistingFile();
//               debugPrint(
//                   "📂 Loaded GPX: ${totalDistance.toStringAsFixed(3)} km, "
//                       "${_getTotalPoints()} pts");
//             } else {
//               _createNewGpxStructure();
//             }
//           } catch (e) {
//             debugPrint("⚠️ Corrupted GPX, creating new: $e");
//             _createNewGpxStructure();
//           }
//         } else {
//           _createNewGpxStructure();
//         }
//       } else {
//         _createNewGpxStructure();
//       }
//     } catch (e) {
//       debugPrint('❌ Error initializing GPX: $e');
//       _createNewGpxStructure();
//     }
//   }
//
//   Future<double> _calculateDistanceFromExistingFile() async {
//     try {
//       if (!await file.exists()) return 0.0;
//       String gpxContent = await file.readAsString();
//       if (gpxContent.isEmpty) return 0.0;
//       Gpx existingGpx = GpxReader().fromString(gpxContent);
//       double existingDistance = 0.0;
//       for (var trk in existingGpx.trks) {
//         for (var seg in trk.trksegs) {
//           if (seg.trkpts.length < 2) continue;
//           for (int i = 0; i < seg.trkpts.length - 1; i++) {
//             existingDistance += calculateDistance(
//               seg.trkpts[i].lat?.toDouble() ?? 0.0,
//               seg.trkpts[i].lon?.toDouble() ?? 0.0,
//               seg.trkpts[i + 1].lat?.toDouble() ?? 0.0,
//               seg.trkpts[i + 1].lon?.toDouble() ?? 0.0,
//             );
//           }
//         }
//       }
//       return existingDistance;
//     } catch (e) {
//       debugPrint("❌ Error calculating existing distance: $e");
//       return 0.0;
//     }
//   }
//
//   void _createNewGpxStructure() {
//     gpx = Gpx();
//     track = Trk();
//     segment = Trkseg();
//     _segments = [];
//     track.trksegs.add(segment);
//     gpx.trks.add(track);
//     isFirstRun = true;
//     file.createSync(recursive: true);
//     totalDistance = 0.0;
//     debugPrint("📁 New GPX file created");
//   }
//
//   // ── Core: handle each incoming GPS position ─────────────────────────────────
//   Future<void> _handleLocationUpdate(Position position) async {
//     final now = DateTime.now();
//
//     // ── Step 1: Accuracy gate ────────────────────────────────────────────────
//     if (position.accuracy > _maxAcceptableAccuracy) {
//       _consecutiveLowAccuracy++;
//       debugPrint("⚠️ Low accuracy ${position.accuracy.toStringAsFixed(1)}m "
//           "($_consecutiveLowAccuracy/5)");
//       if (_consecutiveLowAccuracy <= 5) return; // skip until GPS stabilises
//     } else {
//       _consecutiveLowAccuracy = 0;
//     }
//
//     // ── Step 2: Outlier / jump rejection ────────────────────────────────────
//     if (!_outlierDetector.isValid(
//         position.latitude, position.longitude, position.accuracy, now)) {
//       return; // impossible jump — discard
//     }
//
//     // ── Step 3: Kalman smoothing ─────────────────────────────────────────────
//     final smoothed = _kalman.process(
//       position.latitude,
//       position.longitude,
//       position.accuracy,
//       now.millisecondsSinceEpoch,
//     );
//     final smoothLat = smoothed[0];
//     final smoothLon = smoothed[1];
//
//     // Update public lat/lon with smoothed values
//     lat = smoothLat.toString();
//     longi = smoothLon.toString();
//
//     // ── Step 4: Distance + time gate ────────────────────────────────────────
//     bool shouldAddPoint = false;
//     double segmentDistance = 0.0;
//     int secondsSinceLast = _lastPointTime != null
//         ? now.difference(_lastPointTime!).inSeconds
//         : 999;
//
//     if (lastTrackPoint != null) {
//       // Measure distance from last *recorded* smoothed point
//       segmentDistance = calculateDistance(
//         lastTrackPoint!.latitude,
//         lastTrackPoint!.longitude,
//         smoothLat,
//         smoothLon,
//       );
//
//       final movedEnough = segmentDistance * 1000 >= _minDistanceFilter;
//       final timeExpired = secondsSinceLast >= _maxTimeBetweenPoints;
//
//       if (movedEnough || timeExpired) {
//         shouldAddPoint = true;
//         if (movedEnough) totalDistance += segmentDistance;
//         debugPrint(
//             "📍 ${timeExpired && !movedEnough ? '⏰ TIME' : '📏 DIST'} | "
//                 "Δ${(segmentDistance * 1000).toStringAsFixed(1)}m | "
//                 "${secondsSinceLast}s | "
//                 "acc ${position.accuracy.toStringAsFixed(1)}m | "
//                 "${totalDistance.toStringAsFixed(3)} km | "
//                 "${_getTotalPoints()} pts");
//       }
//     } else {
//       shouldAddPoint = true;
//       debugPrint("🎯 First point (acc ${position.accuracy.toStringAsFixed(1)}m)");
//     }
//
//     // ── Step 5: Write track point using SMOOTHED coordinates ────────────────
//     if (shouldAddPoint) {
//       final trackPoint = Wpt(
//         lat: smoothLat,
//         lon: smoothLon,
//         time: now,
//         ele: position.altitude,
//         name: (position.speed * 3.6) > 1.0 ? 'moving' : 'stationary',
//       );
//
//       segment.trkpts.add(trackPoint);
//       _lastPointTime = now;
//
//       // Update lastTrackPoint with smoothed coordinates for next distance calc
//       lastTrackPoint = Position(
//         latitude: smoothLat,
//         longitude: smoothLon,
//         accuracy: position.accuracy,
//         altitude: position.altitude,
//         altitudeAccuracy: position.altitudeAccuracy ?? 0,
//         heading: position.heading,
//         headingAccuracy: position.headingAccuracy ?? 0,
//         speed: position.speed,
//         speedAccuracy: position.speedAccuracy ?? 0,
//         timestamp: position.timestamp,
//       );
//
//       if (segment.trkpts.length > 5000) {
//         await _startNewSegment();
//       }
//
//       _debouncedUpdateGpxFile();
//     } else {
//       // Still update lastTrackPoint's raw reference for outlier detector
//       lastTrackPoint = Position(
//         latitude: smoothLat,
//         longitude: smoothLon,
//         accuracy: position.accuracy,
//         altitude: position.altitude,
//         altitudeAccuracy: position.altitudeAccuracy ?? 0,
//         heading: position.heading,
//         headingAccuracy: position.headingAccuracy ?? 0,
//         speed: position.speed,
//         speedAccuracy: position.speedAccuracy ?? 0,
//         timestamp: position.timestamp,
//       );
//     }
//   }
//
//   void _debouncedUpdateGpxFile() {
//     _pendingWrite = true;
//     _writeDebounceTimer?.cancel();
//     _writeDebounceTimer = Timer(_writeDebounceDelay, _performFileWrite);
//   }
//
//   Future<void> _performFileWrite() async {
//     if (!_pendingWrite) return;
//     await _fileWriteLock.synchronized(() async {
//       try {
//         if (_segments.isNotEmpty) {
//           track.trksegs = List<Trkseg>.from(_segments);
//           if (!track.trksegs.contains(segment)) {
//             track.trksegs.add(segment);
//           }
//         }
//         gpxString = GpxWriter().asString(gpx, pretty: true);
//         await file.writeAsString(gpxString, flush: true);
//         _pendingWrite = false;
//         debugPrint("💾 GPX: ${track.trksegs.length} segs | "
//             "${_getTotalPoints()} pts | "
//             "${(await file.length() / 1024).toStringAsFixed(1)} KB");
//       } catch (e) {
//         debugPrint('❌ Error writing GPX: $e');
//       }
//     });
//   }
//
//   double getCurrentDistance() =>
//       double.parse(totalDistance.toStringAsFixed(3));
//
//   Future<double> calculateCurrentDistance() async {
//     try {
//       if (!await file.exists()) return totalDistance;
//       String gpxContent = await file.readAsString();
//       if (gpxContent.isEmpty) return totalDistance;
//
//       Gpx g = GpxReader().fromString(gpxContent);
//       double calc = 0.0;
//       for (var trk in g.trks) {
//         for (var seg in trk.trksegs) {
//           if (seg.trkpts.length < 2) continue;
//           for (int i = 0; i < seg.trkpts.length - 1; i++) {
//             calc += calculateDistance(
//               seg.trkpts[i].lat?.toDouble() ?? 0.0,
//               seg.trkpts[i].lon?.toDouble() ?? 0.0,
//               seg.trkpts[i + 1].lat?.toDouble() ?? 0.0,
//               seg.trkpts[i + 1].lon?.toDouble() ?? 0.0,
//             );
//           }
//         }
//       }
//       totalDistance = calc > totalDistance ? calc : totalDistance;
//       return totalDistance;
//     } catch (e) {
//       debugPrint('❌ Error calculating distance: $e');
//       return totalDistance;
//     }
//   }
//
//   int _getTotalPoints() {
//     int total = 0;
//     for (var seg in track.trksegs) {
//       total += seg.trkpts.length;
//     }
//     return total;
//   }
//
//   Future<void> init() async {
//     SharedPreferences pref = await SharedPreferences.getInstance();
//     await pref.reload();
//     userNameForLocation = pref.getString("userName") ?? "USERName";
//     userIdForLocation = pref.getString("userId") ?? "USERId";
//     nsmIdForLocation = pref.getString("userNSM") ?? "nsmUSER";
//     rsmIdForLocation = pref.getString("userRSM") ?? "rsmUSER";
//     smIdForLocation = pref.getString("userSM") ?? "smUSER";
//     dispatcherIdForLocation =
//         pref.getString("userDISPATCHER") ?? "dispatcherUSER";
//     userCityForLocatiion = pref.getString("userCity") ?? "CITY";
//     userDesignationForLocation =
//         pref.getString("userDesignation") ?? "DESIGNATION";
//   }
//
//   double calculateDistance(
//       double lat1, double lon1, double lat2, double lon2) {
//     return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000.0;
//   }
//
//   Future<void> stopListening() async {
//     try {
//       positionStream?.cancel();
//       _forcedUpdateTimer?.cancel();
//       _writeDebounceTimer?.cancel();
//       if (_pendingWrite) await _performFileWrite();
//       await calculateCurrentDistance();
//
//       SharedPreferences pref = await SharedPreferences.getInstance();
//       await pref.setDouble("TotalDistance", totalDistance);
//       await pref.setString(
//           "lastSessionEnd", DateTime.now().toIso8601String());
//
//       debugPrint(
//           "🛑 Stopped. ${totalDistance.toStringAsFixed(3)} km | ${_getTotalPoints()} pts");
//     } catch (e) {
//       debugPrint("❌ ERROR in stopListening: $e");
//     }
//   }
//
//   void resetDistance() {
//     totalDistance = 0.0;
//     _kalman.reset();
//     _outlierDetector.reset();
//     debugPrint("🔄 Distance + filters reset");
//   }
//
//   Map<String, dynamic> getServiceStatus() {
//     return {
//       'isInitialized': _isInitialized,
//       'isFirstLocationRecorded': _isFirstLocationRecorded,
//       'totalDistance': totalDistance,
//       'pointsRecorded': segment.trkpts.length,
//       'totalSegments': track.trksegs.length,
//       'totalAllPoints': _getTotalPoints(),
//       'lastTrackPoint': lastTrackPoint != null
//           ? '${lastTrackPoint!.latitude.toStringAsFixed(6)}, '
//           '${lastTrackPoint!.longitude.toStringAsFixed(6)}'
//           : 'None',
//       'filePath': file.path,
//       'fileExists': file.existsSync(),
//       'fileSize': file.existsSync() ? file.lengthSync() : 0,
//       'pendingWrite': _pendingWrite,
//       'mode': 'KALMAN_SMOOTH',
//       'accuracy': lastTrackPoint?.accuracy,
//       'kalmanInitialized': _kalman.isInitialized,
//     };
//   }
//
//   Future<String> getGpxContent() async {
//     try {
//       if (await file.exists()) return await file.readAsString();
//       return gpxString;
//     } catch (e) {
//       debugPrint("❌ Error reading GPX: $e");
//       return "";
//     }
//   }
//
//   Future<String> getConsolidatedGpx() async {
//     try {
//       Gpx consolidated = Gpx();
//       Trk consolidatedTrack = Trk()
//         ..name = "Track ${DateFormat('dd-MM-yyyy').format(DateTime.now())}";
//       for (var seg in track.trksegs) {
//         if (seg.trkpts.isNotEmpty) consolidatedTrack.trksegs.add(seg);
//       }
//       consolidated.trks.add(consolidatedTrack);
//       return GpxWriter().asString(consolidated, pretty: true);
//     } catch (e) {
//       debugPrint("❌ Error consolidating GPX: $e");
//       return gpxString;
//     }
//   }
//
//   Future<void> saveGpxFile(String filePath) async {
//     try {
//       File outputFile = File(filePath);
//       String content = await getConsolidatedGpx();
//       await outputFile.writeAsString(content, flush: true);
//       debugPrint("💾 GPX saved: $filePath");
//     } catch (e) {
//       debugPrint("❌ Error saving GPX: $e");
//     }
//   }
// }


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