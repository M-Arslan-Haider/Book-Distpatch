// // ============================================================
// //  mqtt_work.dart — GPS MQTT Tracker (INTEGRATED INTO TIMER_CARD)
// //  ✅ Clock In/Out linking via TimerCard._handleClockIn/Out
// //  ✅ FIX: companyCode & empName passed directly — no key mismatch
// //  ✅ NEW: startService() called on native MethodChannel at clock-in
// //          so the Kotlin foreground service takes over in background/killed state.
// // ============================================================
//
// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:mqtt_client/mqtt_client.dart';
// import 'package:mqtt_client/mqtt_server_client.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart' as p;
//
// const String _mqttHost  = '103.149.33.102';
// const int    _mqttPort  = 1883;
//
// // MethodChannel to control Kotlin background service
// const _serviceChannel = MethodChannel('com.example.untitled2/mqtt_service');
//
// class MqttTracker {
//   String get _mqttTopic => 'gps/$_companyCode/$_deviceId';
//   static final MqttTracker _instance = MqttTracker._internal();
//
//   factory MqttTracker() => _instance;
//   MqttTracker._internal();
//
//   // ================================================================== //
//   //  State
//   // ================================================================== //
//   bool _isMqttConnected       = false;
//   bool _isConnecting          = false;
//   bool _intentionalDisconnect = false;
//
//   double? _lat, _lon, _accuracy, _speed;
//   int _publishCount = 0;
//   int _queuedCount  = 0;
//
//   Timer? _locationTimer, _reconnectTimer, _queueFlushTimer;
//   MqttServerClient? _mqttClient;
//
//   String    _deviceId    = 'DEVICE_000';
//   String    _companyCode = '';
//   String    _empName     = '';
//   Database? _db;
//
//   // ================================================================== //
//   //  Getters
//   // ================================================================== //
//   bool get isMqttConnected => _isMqttConnected;
//   bool get isConnecting    => _isConnecting;
//   int  get queuedCount     => _queuedCount;
//   int  get publishCount    => _publishCount;
//
//   // ================================================================== //
//   //  Initialization
//   // ================================================================== //
//
//   Future<void> initialize() async {
//     debugPrint('🚀 [MqttTracker] initialize() — start');
//     await _initDb();
//     await _initializeDeviceId();
//     await _refreshQueueCount();
//     debugPrint(
//         '🚀 [MqttTracker] initialize() — done | deviceId=$_deviceId | '
//             'company=$_companyCode | emp=$_empName | queued=$_queuedCount');
//   }
//
//   // ================================================================== //
//   //  SQLite — Unlimited Offline Queue
//   // ================================================================== //
//
//   Future<void> _initDb() async {
//     debugPrint('🗄️ [DB] _initDb() — opening gps_queue.db');
//     try {
//       final dbPath = await getDatabasesPath();
//       debugPrint('🗄️ [DB] path: $dbPath');
//       _db = await openDatabase(
//         p.join(dbPath, 'gps_queue.db'),
//         version: 1,
//         onCreate: (db, _) async {
//           debugPrint('🗄️ [DB] onCreate — creating offline_queue table');
//           await db.execute('''
//             CREATE TABLE offline_queue (
//               id      INTEGER PRIMARY KEY AUTOINCREMENT,
//               payload TEXT    NOT NULL,
//               created INTEGER NOT NULL
//             )
//           ''');
//           debugPrint('🗄️ [DB] table created');
//         },
//       );
//       debugPrint('🗄️ [DB] opened successfully');
//     } catch (e) {
//       debugPrint('❌ [DB] SQLite init error: $e');
//     }
//   }
//
//   Future<void> _enqueueOffline(Map<String, dynamic> payload) async {
//     debugPrint('💾 [Queue] _enqueueOffline() — MQTT not connected, saving locally');
//     try {
//       if (_db == null) {
//         debugPrint('💾 [Queue] DB was null — re-initialising');
//         await _initDb();
//       }
//       final encoded = jsonEncode(payload);
//       debugPrint('💾 [Queue] payload: $encoded');
//       await _db!.insert('offline_queue', {
//         'payload': encoded,
//         'created': DateTime.now().millisecondsSinceEpoch,
//       });
//       await _refreshQueueCount();
//       debugPrint('💾 [Queue] saved | total queued: $_queuedCount');
//     } catch (e) {
//       debugPrint('❌ [Queue] error: $e');
//     }
//   }
//
//   Future<void> _flushOfflineQueue() async {
//     debugPrint('🔁 [Flush] _flushOfflineQueue() — connected=$_isMqttConnected');
//     if (!_isMqttConnected || _mqttClient == null) {
//       debugPrint('🔁 [Flush] skipped — not connected');
//       return;
//     }
//     try {
//       if (_db == null) {
//         debugPrint('🔁 [Flush] DB null — re-initialising');
//         await _initDb();
//       }
//
//       final rows = await _db!.query('offline_queue', orderBy: 'created ASC');
//       debugPrint('🔁 [Flush] rows to flush: ${rows.length}');
//       if (rows.isEmpty) return;
//
//       int sent = 0;
//       for (final row in rows) {
//         if (!_isMqttConnected) {
//           debugPrint('🔁 [Flush] lost connection mid-flush — stopping');
//           break;
//         }
//         try {
//           debugPrint(
//               '🔁 [Flush] sending id=${row['id']} payload=${row['payload']}');
//           final builder = MqttClientPayloadBuilder()
//             ..addString(row['payload'] as String);
//           _mqttClient!.publishMessage(
//               _mqttTopic, MqttQos.atLeastOnce, builder.payload!,
//               retain: false);
//
//           await _db!.delete('offline_queue',
//               where: 'id = ?', whereArgs: [row['id']]);
//           _publishCount++;
//           sent++;
//           debugPrint(
//               '🔁 [Flush] sent id=${row['id']} | total published=$_publishCount');
//         } catch (e) {
//           debugPrint('❌ [Flush] failed for id=${row['id']}: $e');
//         }
//       }
//
//       await _refreshQueueCount();
//       debugPrint('✅ [Flush] done | sent=$sent | remaining=$_queuedCount');
//     } catch (e) {
//       debugPrint('❌ [Flush] error: $e');
//     }
//   }
//
//   Future<void> _refreshQueueCount() async {
//     try {
//       if (_db == null) return;
//       final result =
//       await _db!.rawQuery('SELECT COUNT(*) as cnt FROM offline_queue');
//       final count  = (result.first['cnt'] as int?) ?? 0;
//       _queuedCount = count;
//       debugPrint('📊 [Queue] count refreshed: $_queuedCount');
//     } catch (e) {
//       debugPrint('❌ [Queue] _refreshQueueCount error: $e');
//     }
//   }
//
//   // ================================================================== //
//   //  Device ID Initialization (used only at app start / restore)
//   // ================================================================== //
//
//   Future<void> _initializeDeviceId() async {
//     debugPrint(
//         '👤 [DeviceId] _initializeDeviceId() — reading SharedPreferences');
//     try {
//       final prefs     = await SharedPreferences.getInstance();
//       final savedName = prefs.getString('user_name') ?? '';
//       debugPrint('👤 [DeviceId] user_name from prefs: "$savedName"');
//
//       if (savedName.isNotEmpty) {
//         _deviceId = savedName;
//         debugPrint('👤 [DeviceId] using saved name: $_deviceId');
//       } else {
//         _deviceId = 'USER_${DateTime.now().millisecondsSinceEpoch}';
//         debugPrint('👤 [DeviceId] no saved name — generated: $_deviceId');
//       }
//
//       // NOTE: companyCode / empName are NOT read from prefs here because
//       // the prefs key used by code_screen.dart (prefCompanyCode constant)
//       // differs from the hardcoded 'company_code' string.  These values
//       // are instead injected directly via clockInMqtt() at Clock-In time.
//       debugPrint(
//           '👤 [DeviceId] companyCode & empName will be set at clockInMqtt()');
//     } catch (e) {
//       debugPrint('❌ [DeviceId] error: $e');
//     }
//   }
//
//   // ================================================================== //
//   //  MQTT Connect
//   // ================================================================== //
//
//   Future<bool> connectMqtt() async {
//     debugPrint(
//         '📡 [MQTT] connectMqtt() — connected=$_isMqttConnected | connecting=$_isConnecting');
//     if (_isMqttConnected || _isConnecting) {
//       debugPrint(
//           '📡 [MQTT] already connected/connecting — returning $_isMqttConnected');
//       return _isMqttConnected;
//     }
//
//     _isConnecting = true;
//     debugPrint('📡 [MQTT] connecting to $_mqttHost:$_mqttPort ...');
//
//     for (final cfg in [
//       {'protocol': 'v311', 'name': 'MQTT 3.1.1'},
//       {'protocol': 'v31',  'name': 'MQTT 3.1'},
//     ]) {
//       debugPrint('📡 [MQTT] trying protocol ${cfg['name']}');
//       if (await _tryConnect(cfg['protocol']!)) {
//         debugPrint('✅ [MQTT] connected via ${cfg['name']}');
//         _isConnecting = false;
//         return true;
//       }
//       debugPrint('📡 [MQTT] ${cfg['name']} failed — trying next');
//     }
//
//     _isConnecting = false;
//     debugPrint('❌ [MQTT] all protocols failed');
//     return false;
//   }
//
//   Future<bool> _tryConnect(String protocol) async {
//     final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
//     debugPrint(
//         '🔌 [MQTT] _tryConnect() protocol=$protocol clientId=$clientId');
//     try {
//       _mqttClient = MqttServerClient(_mqttHost, clientId)
//         ..port = _mqttPort
//         ..logging(on: false)
//         ..keepAlivePeriod = 30
//         ..secure = false
//         ..useWebSocket = false
//         ..autoReconnect = false
//         ..connectTimeoutPeriod = 8000;
//
//       if (protocol == 'v31') {
//         _mqttClient!.setProtocolV31();
//       } else {
//         _mqttClient!.setProtocolV311();
//       }
//
//       _mqttClient!.onConnected    = _onMqttConnected;
//       _mqttClient!.onDisconnected = _onMqttDisconnected;
//
//       final connMsg = MqttConnectMessage()
//           .withClientIdentifier(clientId)
//           .startClean()
//           .withWillQos(MqttQos.atMostOnce);
//       _mqttClient!.connectionMessage = connMsg;
//
//       debugPrint('🔌 [MQTT] calling connect()...');
//       final status = await _mqttClient!.connect();
//       debugPrint('🔌 [MQTT] connect() returned state=${status?.state}');
//
//       if (status?.state == MqttConnectionState.connected) return true;
//
//       debugPrint('🔌 [MQTT] not connected — state=${status?.state}');
//       _mqttClient!.disconnect();
//       return false;
//     } catch (e) {
//       debugPrint('❌ [MQTT] $protocol exception: $e');
//       try {
//         _mqttClient?.disconnect();
//       } catch (_) {}
//       return false;
//     }
//   }
//
//   void _onMqttConnected() {
//     debugPrint('✅ [MQTT] _onMqttConnected() callback fired');
//     _isMqttConnected = true;
//     debugPrint('✅ [MQTT] state set to connected — flushing offline queue');
//     _flushOfflineQueue();
//   }
//
//   void _onMqttDisconnected() {
//     debugPrint(
//         '⚠️ [MQTT] _onMqttDisconnected() callback fired | intentional=$_intentionalDisconnect');
//     if (_intentionalDisconnect) {
//       _intentionalDisconnect = false;
//       debugPrint('📱 [MQTT] intentional disconnect — handed off to background service');
//       _isMqttConnected = false;
//       return;
//     }
//     _isMqttConnected = false;
//     debugPrint(
//         '⚠️ [MQTT] unexpected disconnect — data will queue locally, starting reconnect timer');
//     _startReconnectTimer();
//   }
//
//   // ================================================================== //
//   //  Publish — saves to SQLite queue if not connected
//   // ================================================================== //
//
//   void publishLocation(
//       double lat, double lon, double accuracy, double speed) {
//     debugPrint(
//         '📍 [Publish] publishLocation() | lat=$lat lon=$lon acc=$accuracy spd=$speed | connected=$_isMqttConnected');
//
//     final payload = {
//       'device_id':    _deviceId,
//       'company_code': _companyCode,
//       'emp_name':     _empName,
//       'track_id':     DateTime.now().millisecondsSinceEpoch,
//       'lat':          lat,
//       'lon':          lon,
//       'accuracy':     accuracy,
//       'speed':        speed,
//       'timestamp':    DateTime.now().toIso8601String(),
//       'source':       'flutter_foreground',
//     };
//     debugPrint('📍 [Publish] payload: ${jsonEncode(payload)}');
//
//     if (!_isMqttConnected || _mqttClient == null) {
//       debugPrint('📍 [Publish] not connected — routing to offline queue');
//       _enqueueOffline(payload);
//       return;
//     }
//
//     try {
//       final builder = MqttClientPayloadBuilder()
//         ..addString(jsonEncode(payload));
//       _mqttClient!.publishMessage(
//           _mqttTopic, MqttQos.atLeastOnce, builder.payload!,
//           retain: false);
//       _publishCount++;
//       debugPrint(
//           '📤 [Publish] ✅ published #$_publishCount to topic=$_mqttTopic');
//     } catch (e) {
//       debugPrint('❌ [Publish] error: $e — routing to offline queue');
//       _enqueueOffline(payload);
//       _isMqttConnected = false;
//     }
//   }
//
//   // ================================================================== //
//   //  Location Updates (called during Clock In)
//   // ================================================================== //
//
//   void startLocationPublishing() {
//     debugPrint('📍 [Location] startLocationPublishing() — starting 5s timer');
//     _locationTimer?.cancel();
//     _locationTimer =
//         Timer.periodic(const Duration(seconds: 5), (_) async {
//           debugPrint('📍 [Location] timer tick — fetching GPS position');
//           try {
//             final pos = await Geolocator.getCurrentPosition(
//               locationSettings: const LocationSettings(
//                   accuracy: LocationAccuracy.high,
//                   timeLimit: Duration(seconds: 5)),
//             );
//             _lat      = pos.latitude;
//             _lon      = pos.longitude;
//             _accuracy = pos.accuracy;
//             _speed    = pos.speed;
//             debugPrint(
//                 '📍 [Location] got fix | lat=$_lat lon=$_lon acc=$_accuracy spd=$_speed');
//
//             publishLocation(
//                 pos.latitude, pos.longitude, pos.accuracy, pos.speed);
//           } catch (e) {
//             debugPrint('❌ [Location] GPS error: $e');
//           }
//         });
//     debugPrint('📍 [Location] timer started');
//   }
//
//   void stopLocationPublishing() {
//     debugPrint('🛑 [Location] stopLocationPublishing() — cancelling timer');
//     _locationTimer?.cancel();
//     _locationTimer = null;
//     debugPrint('🛑 [Location] timer cancelled');
//   }
//
//   // ================================================================== //
//   //  Reconnect Timer
//   // ================================================================== //
//
//   void _startReconnectTimer() {
//     debugPrint('🔄 [Reconnect] _startReconnectTimer() — will retry every 10s');
//     _reconnectTimer?.cancel();
//     _reconnectTimer =
//         Timer.periodic(const Duration(seconds: 10), (_) async {
//           debugPrint('🔄 [Reconnect] tick — connected=$_isMqttConnected');
//           if (_isMqttConnected) {
//             debugPrint('🔄 [Reconnect] already connected — cancelling timer');
//             _reconnectTimer?.cancel();
//             return;
//           }
//           debugPrint('🔄 [Reconnect] retrying MQTT connect...');
//           final ok = await connectMqtt();
//           if (ok) {
//             _reconnectTimer?.cancel();
//             debugPrint('✅ [Reconnect] reconnected successfully — flushing queue');
//             await _flushOfflineQueue();
//           } else {
//             debugPrint('❌ [Reconnect] retry failed — will try again in 10s');
//           }
//         });
//   }
//
//   void _startQueueFlushTimer() {
//     debugPrint(
//         '⏱️ [FlushTimer] _startQueueFlushTimer() — will flush every 30s');
//     _queueFlushTimer?.cancel();
//     _queueFlushTimer =
//         Timer.periodic(const Duration(seconds: 30), (_) {
//           debugPrint(
//               '⏱️ [FlushTimer] tick — connected=$_isMqttConnected | queued=$_queuedCount');
//           if (_isMqttConnected) {
//             _flushOfflineQueue();
//           } else {
//             debugPrint('⏱️ [FlushTimer] not connected — skipping flush');
//           }
//         });
//   }
//
//   // ================================================================== //
//   //  Clock In (called from timer_card.dart)
//   //  ✅ FIX: companyCode & empName are injected directly — no prefs key
//   //          mismatch. In timer_card.dart call it like:
//   //
//   //    final mqttOk = await _mqttTracker.clockInMqtt(
//   //      deviceId    : empId,
//   //      companyCode : prefs.getString(prefCompanyCode) ?? '',
//   //      empName     : empName,
//   //    );
//   //
//   //  ✅ NEW: Starts the Kotlin foreground service via MethodChannel so
//   //          location+MQTT publishing continues in background & killed state.
//   // ================================================================== //
//
//   Future<bool> clockInMqtt({
//     required String deviceId,
//     required String companyCode,
//     required String empName,
//   }) async {
//     debugPrint(
//         '🟢 [ClockIn] clockInMqtt() — deviceId=$deviceId | company=$companyCode | emp=$empName');
//
//     // ── Set identity fields directly — no prefs key lookup needed ──────
//     _deviceId    = deviceId;
//     _companyCode = companyCode;
//     _empName     = empName;
//
//     if (_companyCode.isEmpty) {
//       debugPrint('⚠️ [ClockIn] companyCode is EMPTY — check prefCompanyCode in timer_card.dart');
//     }
//     if (_empName.isEmpty) {
//       debugPrint('⚠️ [ClockIn] empName is EMPTY — check empName read in timer_card.dart');
//     }
//
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('user_name', deviceId);
//     await prefs.setBool('flutter.isClockedIn', true);
//     await prefs.setInt(
//         'flutter.clockInTimeMs', DateTime.now().millisecondsSinceEpoch);
//     debugPrint(
//         '🟢 [ClockIn] prefs saved | isClockedIn=true | clockInTime=${DateTime.now()}');
//
//     // ── ✅ NEW: Start Kotlin foreground service ──────────────────────────
//     // The service runs independently in a separate Android context and
//     // continues publishing lat/lng every 5s even when the app is in
//     // background or has been swiped from Recents.
//     try {
//       await _serviceChannel.invokeMethod('startService', {
//         'deviceId':    deviceId,
//         'companyCode': companyCode,
//         'empName':     empName,
//       });
//       debugPrint('🟢 [ClockIn] ✅ Kotlin background service started');
//     } catch (e) {
//       debugPrint('⚠️ [ClockIn] Could not start background service: $e');
//       // Non-fatal — Flutter foreground MQTT still handles the in-app state
//     }
//
//     debugPrint('🟢 [ClockIn] attempting MQTT connect...');
//     final ok = await connectMqtt();
//     if (ok) {
//       debugPrint('🟢 [ClockIn] MQTT connected — starting location publishing');
//       startLocationPublishing();
//       _startQueueFlushTimer();
//       debugPrint('✅ [ClockIn] complete');
//       return true;
//     } else {
//       debugPrint(
//           '⚠️ [ClockIn] MQTT unavailable — starting offline mode with reconnect timer');
//       startLocationPublishing();
//       _startReconnectTimer();
//       _startQueueFlushTimer();
//       return false;
//     }
//   }
//
//   // ================================================================== //
//   //  Clock Out (called from timer_card.dart)
//   // ================================================================== //
//
//   Future<void> clockOutMqtt() async {
//     debugPrint(
//         '🔴 [ClockOut] clockOutMqtt() — stopping location, cancelling timers');
//     stopLocationPublishing();
//     _reconnectTimer?.cancel();
//     _queueFlushTimer?.cancel();
//     debugPrint('🔴 [ClockOut] timers cancelled');
//
//     if (_isMqttConnected) {
//       debugPrint('🔴 [ClockOut] connected — flushing queue before disconnect');
//       await _flushOfflineQueue();
//     } else {
//       debugPrint(
//           '🔴 [ClockOut] not connected — skipping flush (queued=$_queuedCount msgs will send on next Clock In)');
//     }
//
//     _intentionalDisconnect = true;
//     debugPrint('🔴 [ClockOut] disconnecting MQTT client');
//     try {
//       _mqttClient?.disconnect();
//     } catch (e) {
//       debugPrint('⚠️ [ClockOut] disconnect error: $e');
//     }
//
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('flutter.isClockedIn', false);
//     await prefs.remove('flutter.clockInTimeMs');
//     debugPrint('🔴 [ClockOut] prefs updated | isClockedIn=false');
//
//     try {
//       debugPrint('🔴 [ClockOut] invoking stopService on background channel');
//       await _serviceChannel.invokeMethod('stopService');
//       debugPrint('🔴 [ClockOut] background service stopped');
//     } catch (e) {
//       debugPrint(
//           '⚠️ [ClockOut] stopService error (may not be running): $e');
//     }
//
//     debugPrint('✅ [ClockOut] complete');
//   }
//
//   // ================================================================== //
//   //  Cleanup
//   // ================================================================== //
//
//   Future<void> dispose() async {
//     debugPrint('🧹 [Dispose] dispose() — cleaning up all resources');
//     stopLocationPublishing();
//     _reconnectTimer?.cancel();
//     _queueFlushTimer?.cancel();
//     _intentionalDisconnect = true;
//     try {
//       _mqttClient?.disconnect();
//     } catch (e) {
//       debugPrint('⚠️ [Dispose] disconnect error: $e');
//     }
//     await _db?.close();
//     debugPrint('🧹 [Dispose] done');
//   }
// }

// ============================================================
//  mqtt_work.dart — GPS MQTT Tracker (INTEGRATED INTO TIMER_CARD)
//  ✅ Clock In/Out linking via TimerCard._handleClockIn/Out
//  ✅ FIX: companyCode & empName passed directly — no key mismatch
//  ✅ NEW: startService() called on native MethodChannel at clock-in
//          so the Kotlin foreground service takes over in background/killed state.
//  ✅ NEW: Network connectivity monitoring for automatic reconnect when internet returns
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';

const String _mqttHost  = '103.149.33.102';
const int    _mqttPort  = 1883;

// MethodChannel to control Kotlin background service
const _serviceChannel = MethodChannel('com.example.untitled2/mqtt_service');

class MqttTracker {
  String get _mqttTopic => 'gps/$_companyCode/$_deviceId';
  static final MqttTracker _instance = MqttTracker._internal();

  factory MqttTracker() => _instance;
  MqttTracker._internal();

  // ================================================================== //
  //  State
  // ================================================================== //
  bool _isMqttConnected       = false;
  bool _isConnecting          = false;
  bool _intentionalDisconnect = false;

  double? _lat, _lon, _accuracy, _speed;
  int _publishCount = 0;
  int _queuedCount  = 0;

  Timer? _locationTimer, _reconnectTimer, _queueFlushTimer;
  MqttServerClient? _mqttClient;

  String    _deviceId    = 'DEVICE_000';
  String    _companyCode = '';
  String    _empName     = '';
  Database? _db;

  // Network monitoring
  List<ConnectivityResult> _lastConnectivity = [ConnectivityResult.none];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // ================================================================== //
  //  Getters
  // ================================================================== //
  bool get isMqttConnected => _isMqttConnected;
  bool get isConnecting    => _isConnecting;
  int  get queuedCount     => _queuedCount;
  int  get publishCount    => _publishCount;

  // ================================================================== //
  //  Initialization
  // ================================================================== //

  Future<void> initialize() async {
    debugPrint('🚀 [MqttTracker] initialize() — start');
    await _initDb();
    await _initializeDeviceId();
    await _refreshQueueCount();
    await _initNetworkMonitoring();
    debugPrint(
        '🚀 [MqttTracker] initialize() — done | deviceId=$_deviceId | '
            'company=$_companyCode | emp=$_empName | queued=$_queuedCount');
  }

  // ================================================================== //
  //  Network Monitoring
  // ================================================================== //

  Future<void> _initNetworkMonitoring() async {
    debugPrint('🌐 [Network] Initializing connectivity monitoring');

    final connectivity = Connectivity();

    // Get initial state
    _lastConnectivity = await connectivity.checkConnectivity();
    debugPrint('🌐 [Network] Initial connectivity: $_lastConnectivity');

    // Listen for changes
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
          (List<ConnectivityResult> results) {
        _handleConnectivityChange(results);
      },
    );
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    // Check if any network is available
    final hasNetwork = results.isNotEmpty &&
        !results.contains(ConnectivityResult.none);
    final hadNetwork = _lastConnectivity.isNotEmpty &&
        !_lastConnectivity.contains(ConnectivityResult.none);

    debugPrint('🌐 [Network] Change detected | had=$hadNetwork | has=$hasNetwork | '
        'connected=$_isMqttConnected | clockedIn=${_companyCode.isNotEmpty}');

    // Network came back online
    if (!hadNetwork && hasNetwork && _companyCode.isNotEmpty) {
      debugPrint('🌐 [Network] Internet restored! Attempting MQTT reconnect...');
      _reconnectAfterNetworkRestore();
    }

    // Network was lost
    if (hadNetwork && !hasNetwork) {
      debugPrint('🌐 [Network] Internet lost - MQTT will queue data');
      _isMqttConnected = false;
    }

    _lastConnectivity = results;
  }
  Future<void> _reconnectAfterNetworkRestore() async {
    if (_companyCode.isEmpty) {
      debugPrint('🌐 [Network] Not clocked in - skipping reconnect');
      return;
    }

    // Cancel any existing reconnect timer to avoid conflicts
    _reconnectTimer?.cancel();

    // Small delay to let network stabilize
    await Future.delayed(const Duration(milliseconds: 500));

    if (!_isMqttConnected && _companyCode.isNotEmpty) {
      debugPrint('🌐 [Network] Executing reconnect...');
      final connected = await connectMqtt();
      if (connected) {
        debugPrint('🌐 [Network] ✅ Reconnected successfully after network restore');
        await _flushOfflineQueue();
      } else {
        debugPrint('🌐 [Network] ❌ Reconnect failed, will retry');
        _startReconnectTimer();
      }
    }
  }

  void stopNetworkMonitoring() {
    debugPrint('🌐 [Network] Stopping connectivity monitoring');
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  // ================================================================== //
  //  SQLite — Unlimited Offline Queue
  // ================================================================== //

  Future<void> _initDb() async {
    debugPrint('🗄️ [DB] _initDb() — opening gps_queue.db');
    try {
      final dbPath = await getDatabasesPath();
      debugPrint('🗄️ [DB] path: $dbPath');
      _db = await openDatabase(
        p.join(dbPath, 'gps_queue.db'),
        version: 1,
        onCreate: (db, _) async {
          debugPrint('🗄️ [DB] onCreate — creating offline_queue table');
          await db.execute('''
            CREATE TABLE offline_queue (
              id      INTEGER PRIMARY KEY AUTOINCREMENT,
              payload TEXT    NOT NULL,
              created INTEGER NOT NULL
            )
          ''');
          debugPrint('🗄️ [DB] table created');
        },
      );
      debugPrint('🗄️ [DB] opened successfully');
    } catch (e) {
      debugPrint('❌ [DB] SQLite init error: $e');
    }
  }

  Future<void> _enqueueOffline(Map<String, dynamic> payload) async {
    debugPrint('💾 [Queue] _enqueueOffline() — MQTT not connected, saving locally');
    try {
      if (_db == null) {
        debugPrint('💾 [Queue] DB was null — re-initialising');
        await _initDb();
      }
      final encoded = jsonEncode(payload);
      debugPrint('💾 [Queue] payload: $encoded');
      await _db!.insert('offline_queue', {
        'payload': encoded,
        'created': DateTime.now().millisecondsSinceEpoch,
      });
      await _refreshQueueCount();
      debugPrint('💾 [Queue] saved | total queued: $_queuedCount');
    } catch (e) {
      debugPrint('❌ [Queue] error: $e');
    }
  }

  Future<void> _flushOfflineQueue() async {
    debugPrint('🔁 [Flush] _flushOfflineQueue() — connected=$_isMqttConnected');
    if (!_isMqttConnected || _mqttClient == null) {
      debugPrint('🔁 [Flush] skipped — not connected');
      return;
    }
    try {
      if (_db == null) {
        debugPrint('🔁 [Flush] DB null — re-initialising');
        await _initDb();
      }

      final rows = await _db!.query('offline_queue', orderBy: 'created ASC');
      debugPrint('🔁 [Flush] rows to flush: ${rows.length}');
      if (rows.isEmpty) return;

      int sent = 0;
      for (final row in rows) {
        if (!_isMqttConnected) {
          debugPrint('🔁 [Flush] lost connection mid-flush — stopping');
          break;
        }
        try {
          debugPrint(
              '🔁 [Flush] sending id=${row['id']} payload=${row['payload']}');
          final builder = MqttClientPayloadBuilder()
            ..addString(row['payload'] as String);
          _mqttClient!.publishMessage(
              _mqttTopic, MqttQos.atLeastOnce, builder.payload!,
              retain: false);

          await _db!.delete('offline_queue',
              where: 'id = ?', whereArgs: [row['id']]);
          _publishCount++;
          sent++;
          debugPrint(
              '🔁 [Flush] sent id=${row['id']} | total published=$_publishCount');
        } catch (e) {
          debugPrint('❌ [Flush] failed for id=${row['id']}: $e');
        }
      }

      await _refreshQueueCount();
      debugPrint('✅ [Flush] done | sent=$sent | remaining=$_queuedCount');
    } catch (e) {
      debugPrint('❌ [Flush] error: $e');
    }
  }

  Future<void> _refreshQueueCount() async {
    try {
      if (_db == null) return;
      final result =
      await _db!.rawQuery('SELECT COUNT(*) as cnt FROM offline_queue');
      final count  = (result.first['cnt'] as int?) ?? 0;
      _queuedCount = count;
      debugPrint('📊 [Queue] count refreshed: $_queuedCount');
    } catch (e) {
      debugPrint('❌ [Queue] _refreshQueueCount error: $e');
    }
  }

  // ================================================================== //
  //  Device ID Initialization (used only at app start / restore)
  // ================================================================== //

  Future<void> _initializeDeviceId() async {
    debugPrint(
        '👤 [DeviceId] _initializeDeviceId() — reading SharedPreferences');
    try {
      final prefs     = await SharedPreferences.getInstance();
      final savedName = prefs.getString('user_name') ?? '';
      debugPrint('👤 [DeviceId] user_name from prefs: "$savedName"');

      if (savedName.isNotEmpty) {
        _deviceId = savedName;
        debugPrint('👤 [DeviceId] using saved name: $_deviceId');
      } else {
        _deviceId = 'USER_${DateTime.now().millisecondsSinceEpoch}';
        debugPrint('👤 [DeviceId] no saved name — generated: $_deviceId');
      }

      // NOTE: companyCode / empName are NOT read from prefs here because
      // the prefs key used by code_screen.dart (prefCompanyCode constant)
      // differs from the hardcoded 'company_code' string.  These values
      // are instead injected directly via clockInMqtt() at Clock-In time.
      debugPrint(
          '👤 [DeviceId] companyCode & empName will be set at clockInMqtt()');
    } catch (e) {
      debugPrint('❌ [DeviceId] error: $e');
    }
  }

  // ================================================================== //
  //  MQTT Connect
  // ================================================================== //

  Future<bool> connectMqtt() async {
    debugPrint(
        '📡 [MQTT] connectMqtt() — connected=$_isMqttConnected | connecting=$_isConnecting');
    if (_isMqttConnected || _isConnecting) {
      debugPrint(
          '📡 [MQTT] already connected/connecting — returning $_isMqttConnected');
      return _isMqttConnected;
    }

    _isConnecting = true;
    debugPrint('📡 [MQTT] connecting to $_mqttHost:$_mqttPort ...');

    for (final cfg in [
      {'protocol': 'v311', 'name': 'MQTT 3.1.1'},
      {'protocol': 'v31',  'name': 'MQTT 3.1'},
    ]) {
      debugPrint('📡 [MQTT] trying protocol ${cfg['name']}');
      if (await _tryConnect(cfg['protocol']!)) {
        debugPrint('✅ [MQTT] connected via ${cfg['name']}');
        _isConnecting = false;
        return true;
      }
      debugPrint('📡 [MQTT] ${cfg['name']} failed — trying next');
    }

    _isConnecting = false;
    debugPrint('❌ [MQTT] all protocols failed');
    return false;
  }

  Future<bool> _tryConnect(String protocol) async {
    final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
    debugPrint(
        '🔌 [MQTT] _tryConnect() protocol=$protocol clientId=$clientId');
    try {
      _mqttClient = MqttServerClient(_mqttHost, clientId)
        ..port = _mqttPort
        ..logging(on: false)
        ..keepAlivePeriod = 30
        ..secure = false
        ..useWebSocket = false
        ..autoReconnect = false
        ..connectTimeoutPeriod = 8000;

      if (protocol == 'v31') {
        _mqttClient!.setProtocolV31();
      } else {
        _mqttClient!.setProtocolV311();
      }

      _mqttClient!.onConnected    = _onMqttConnected;
      _mqttClient!.onDisconnected = _onMqttDisconnected;

      final connMsg = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);
      _mqttClient!.connectionMessage = connMsg;

      debugPrint('🔌 [MQTT] calling connect()...');
      final status = await _mqttClient!.connect();
      debugPrint('🔌 [MQTT] connect() returned state=${status?.state}');

      if (status?.state == MqttConnectionState.connected) return true;

      debugPrint('🔌 [MQTT] not connected — state=${status?.state}');
      _mqttClient!.disconnect();
      return false;
    } catch (e) {
      debugPrint('❌ [MQTT] $protocol exception: $e');
      try {
        _mqttClient?.disconnect();
      } catch (_) {}
      return false;
    }
  }

  void _onMqttConnected() {
    debugPrint('✅ [MQTT] _onMqttConnected() callback fired');
    _isMqttConnected = true;
    debugPrint('✅ [MQTT] state set to connected — flushing offline queue');
    _flushOfflineQueue();
  }

  void _onMqttDisconnected() {
    debugPrint(
        '⚠️ [MQTT] _onMqttDisconnected() callback fired | intentional=$_intentionalDisconnect');
    if (_intentionalDisconnect) {
      _intentionalDisconnect = false;
      debugPrint('📱 [MQTT] intentional disconnect — handed off to background service');
      _isMqttConnected = false;
      return;
    }
    _isMqttConnected = false;
    debugPrint(
        '⚠️ [MQTT] unexpected disconnect — data will queue locally, starting reconnect timer');
    _startReconnectTimer();
  }

  // ================================================================== //
  //  Publish — saves to SQLite queue if not connected
  // ================================================================== //

  void publishLocation(
      double lat, double lon, double accuracy, double speed) {
    debugPrint(
        '📍 [Publish] publishLocation() | lat=$lat lon=$lon acc=$accuracy spd=$speed | connected=$_isMqttConnected');

    final payload = {
      'device_id':    _deviceId,
      'company_code': _companyCode,
      'emp_name':     _empName,
      'track_id':     DateTime.now().millisecondsSinceEpoch,
      'lat':          lat,
      'lon':          lon,
      'accuracy':     accuracy,
      'speed':        speed,
      'timestamp':    DateTime.now().toIso8601String(),
      'source':       'flutter_foreground',
    };
    debugPrint('📍 [Publish] payload: ${jsonEncode(payload)}');

    if (!_isMqttConnected || _mqttClient == null) {
      debugPrint('📍 [Publish] not connected — routing to offline queue');
      _enqueueOffline(payload);
      return;
    }

    try {
      final builder = MqttClientPayloadBuilder()
        ..addString(jsonEncode(payload));
      _mqttClient!.publishMessage(
          _mqttTopic, MqttQos.atLeastOnce, builder.payload!,
          retain: false);
      _publishCount++;
      debugPrint(
          '📤 [Publish] ✅ published #$_publishCount to topic=$_mqttTopic');
    } catch (e) {
      debugPrint('❌ [Publish] error: $e — routing to offline queue');
      _enqueueOffline(payload);
      _isMqttConnected = false;
    }
  }

  // ================================================================== //
  //  Location Updates (called during Clock In)
  // ================================================================== //

  void startLocationPublishing() {
    debugPrint('📍 [Location] startLocationPublishing() — starting 5s timer');
    _locationTimer?.cancel();
    _locationTimer =
        Timer.periodic(const Duration(seconds: 5), (_) async {
          debugPrint('📍 [Location] timer tick — fetching GPS position');
          try {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  timeLimit: Duration(seconds: 5)),
            );
            _lat      = pos.latitude;
            _lon      = pos.longitude;
            _accuracy = pos.accuracy;
            _speed    = pos.speed;
            debugPrint(
                '📍 [Location] got fix | lat=$_lat lon=$_lon acc=$_accuracy spd=$_speed');

            publishLocation(
                pos.latitude, pos.longitude, pos.accuracy, pos.speed);
          } catch (e) {
            debugPrint('❌ [Location] GPS error: $e');
          }
        });
    debugPrint('📍 [Location] timer started');
  }

  void stopLocationPublishing() {
    debugPrint('🛑 [Location] stopLocationPublishing() — cancelling timer');
    _locationTimer?.cancel();
    _locationTimer = null;
    debugPrint('🛑 [Location] timer cancelled');
  }

  // ================================================================== //
  //  Reconnect Timer
  // ================================================================== //

  void _startReconnectTimer() {
    debugPrint('🔄 [Reconnect] _startReconnectTimer() — will retry every 10s');
    _reconnectTimer?.cancel();
    _reconnectTimer =
        Timer.periodic(const Duration(seconds: 10), (_) async {
          debugPrint('🔄 [Reconnect] tick — connected=$_isMqttConnected');
          if (_isMqttConnected) {
            debugPrint('🔄 [Reconnect] already connected — cancelling timer');
            _reconnectTimer?.cancel();
            return;
          }
          debugPrint('🔄 [Reconnect] retrying MQTT connect...');
          final ok = await connectMqtt();
          if (ok) {
            _reconnectTimer?.cancel();
            debugPrint('✅ [Reconnect] reconnected successfully — flushing queue');
            await _flushOfflineQueue();
          } else {
            debugPrint('❌ [Reconnect] retry failed — will try again in 10s');
          }
        });
  }

  void _startQueueFlushTimer() {
    debugPrint(
        '⏱️ [FlushTimer] _startQueueFlushTimer() — will flush every 30s');
    _queueFlushTimer?.cancel();
    _queueFlushTimer =
        Timer.periodic(const Duration(seconds: 30), (_) {
          debugPrint(
              '⏱️ [FlushTimer] tick — connected=$_isMqttConnected | queued=$_queuedCount');
          if (_isMqttConnected) {
            _flushOfflineQueue();
          } else {
            debugPrint('⏱️ [FlushTimer] not connected — skipping flush');
          }
        });
  }

  // ================================================================== //
  //  Clock In (called from timer_card.dart)
  //  ✅ FIX: companyCode & empName are injected directly — no prefs key
  //          mismatch. In timer_card.dart call it like:
  //
  //    final mqttOk = await _mqttTracker.clockInMqtt(
  //      deviceId    : empId,
  //      companyCode : prefs.getString(prefCompanyCode) ?? '',
  //      empName     : empName,
  //    );
  //
  //  ✅ NEW: Starts the Kotlin foreground service via MethodChannel so
  //          location+MQTT publishing continues in background & killed state.
  // ================================================================== //

  Future<bool> clockInMqtt({
    required String deviceId,
    required String companyCode,
    required String empName,
  }) async {
    debugPrint(
        '🟢 [ClockIn] clockInMqtt() — deviceId=$deviceId | company=$companyCode | emp=$empName');

    // ── Set identity fields directly — no prefs key lookup needed ──────
    _deviceId    = deviceId;
    _companyCode = companyCode;
    _empName     = empName;

    if (_companyCode.isEmpty) {
      debugPrint('⚠️ [ClockIn] companyCode is EMPTY — check prefCompanyCode in timer_card.dart');
    }
    if (_empName.isEmpty) {
      debugPrint('⚠️ [ClockIn] empName is EMPTY — check empName read in timer_card.dart');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', deviceId);
    await prefs.setBool('flutter.isClockedIn', true);
    await prefs.setInt(
        'flutter.clockInTimeMs', DateTime.now().millisecondsSinceEpoch);
    debugPrint(
        '🟢 [ClockIn] prefs saved | isClockedIn=true | clockInTime=${DateTime.now()}');

    // ── ✅ NEW: Start Kotlin foreground service ──────────────────────────
    // The service runs independently in a separate Android context and
    // continues publishing lat/lng every 5s even when the app is in
    // background or has been swiped from Recents.
    try {
      await _serviceChannel.invokeMethod('startService', {
        'deviceId':    deviceId,
        'companyCode': companyCode,
        'empName':     empName,
      });
      debugPrint('🟢 [ClockIn] ✅ Kotlin background service started');
    } catch (e) {
      debugPrint('⚠️ [ClockIn] Could not start background service: $e');
      // Non-fatal — Flutter foreground MQTT still handles the in-app state
    }

    debugPrint('🟢 [ClockIn] attempting MQTT connect...');
    final ok = await connectMqtt();
    if (ok) {
      debugPrint('🟢 [ClockIn] MQTT connected — starting location publishing');
      startLocationPublishing();
      _startQueueFlushTimer();
      debugPrint('✅ [ClockIn] complete');
      return true;
    } else {
      debugPrint(
          '⚠️ [ClockIn] MQTT unavailable — starting offline mode with reconnect timer');
      startLocationPublishing();
      _startReconnectTimer();
      _startQueueFlushTimer();
      return false;
    }
  }

  // ================================================================== //
  //  Clock Out (called from timer_card.dart)
  // ================================================================== //

  Future<void> clockOutMqtt() async {
    debugPrint(
        '🔴 [ClockOut] clockOutMqtt() — stopping location, cancelling timers');
    stopLocationPublishing();
    stopNetworkMonitoring();
    _reconnectTimer?.cancel();
    _queueFlushTimer?.cancel();
    debugPrint('🔴 [ClockOut] timers cancelled');

    if (_isMqttConnected) {
      debugPrint('🔴 [ClockOut] connected — flushing queue before disconnect');
      await _flushOfflineQueue();
    } else {
      debugPrint(
          '🔴 [ClockOut] not connected — skipping flush (queued=$_queuedCount msgs will send on next Clock In)');
    }

    _intentionalDisconnect = true;
    debugPrint('🔴 [ClockOut] disconnecting MQTT client');
    try {
      _mqttClient?.disconnect();
    } catch (e) {
      debugPrint('⚠️ [ClockOut] disconnect error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('flutter.isClockedIn', false);
    await prefs.remove('flutter.clockInTimeMs');
    debugPrint('🔴 [ClockOut] prefs updated | isClockedIn=false');

    try {
      debugPrint('🔴 [ClockOut] invoking stopService on background channel');
      await _serviceChannel.invokeMethod('stopService');
      debugPrint('🔴 [ClockOut] background service stopped');
    } catch (e) {
      debugPrint(
          '⚠️ [ClockOut] stopService error (may not be running): $e');
    }

    debugPrint('✅ [ClockOut] complete');
  }

  // ================================================================== //
  //  Cleanup
  // ================================================================== //

  Future<void> dispose() async {
    debugPrint('🧹 [Dispose] dispose() — cleaning up all resources');
    stopLocationPublishing();
    stopNetworkMonitoring();
    _reconnectTimer?.cancel();
    _queueFlushTimer?.cancel();
    _intentionalDisconnect = true;
    try {
      _mqttClient?.disconnect();
    } catch (e) {
      debugPrint('⚠️ [Dispose] disconnect error: $e');
    }
    await _db?.close();
    debugPrint('🧹 [Dispose] done');
  }
}