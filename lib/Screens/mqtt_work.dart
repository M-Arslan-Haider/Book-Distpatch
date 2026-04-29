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

const String _mqttHost  = '119.153.102.7';
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
  String    _empImage    = '';
  String    _depId       = '';
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
    if (_companyCode.isEmpty) return;

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
      _db = await openDatabase(
        p.join(dbPath, 'gps_queue.db'),
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE offline_queue (
              id      INTEGER PRIMARY KEY AUTOINCREMENT,
              payload TEXT    NOT NULL,
              created INTEGER NOT NULL
            )
          ''');
        },
      );
    } catch (e) {
      debugPrint('❌ [DB] SQLite init error: $e');
    }
  }

  Future<void> _enqueueOffline(Map<String, dynamic> payload) async {
    try {
      if (_db == null) await _initDb();
      final encoded = jsonEncode(payload);
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
    if (!_isMqttConnected || _mqttClient == null) return;
    try {
      if (_db == null) await _initDb();

      final rows = await _db!.query('offline_queue', orderBy: 'created ASC');
      if (rows.isEmpty) return;

      int sent = 0;
      for (final row in rows) {
        if (!_isMqttConnected) break;
        try {
          final builder = MqttClientPayloadBuilder()
            ..addString(row['payload'] as String);
          _mqttClient!.publishMessage(
              _mqttTopic, MqttQos.atLeastOnce, builder.payload!,
              retain: false);

          await _db!.delete('offline_queue',
              where: 'id = ?', whereArgs: [row['id']]);
          _publishCount++;
          sent++;
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
      _queuedCount = (result.first['cnt'] as int?) ?? 0;
    } catch (_) {}
  }

  // ================================================================== //
  //  Device ID Initialization
  // ================================================================== //

  Future<void> _initializeDeviceId() async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final savedName = prefs.getString('user_name') ?? '';
      if (savedName.isNotEmpty) {
        _deviceId = savedName;
      } else {
        _deviceId = 'USER_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      debugPrint('❌ [DeviceId] error: $e');
    }
  }

  // ================================================================== //
  //  MQTT Connect
  // ================================================================== //

  Future<bool> connectMqtt() async {
    if (_isMqttConnected || _isConnecting) return _isMqttConnected;

    _isConnecting = true;

    for (final cfg in [
      {'protocol': 'v311', 'name': 'MQTT 3.1.1'},
      {'protocol': 'v31',  'name': 'MQTT 3.1'},
    ]) {
      if (await _tryConnect(cfg['protocol']!)) {
        _isConnecting = false;
        return true;
      }
    }

    _isConnecting = false;
    return false;
  }

  Future<bool> _tryConnect(String protocol) async {
    final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
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

      final status = await _mqttClient!.connect();

      if (status?.state == MqttConnectionState.connected) return true;
      _mqttClient!.disconnect();
      return false;
    } catch (e) {
      debugPrint('❌ [MQTT] $protocol exception: $e');
      try { _mqttClient?.disconnect(); } catch (_) {}
      return false;
    }
  }

  void _onMqttConnected() {
    _isMqttConnected = true;
    _flushOfflineQueue();
  }

  void _onMqttDisconnected() {
    if (_intentionalDisconnect) {
      _intentionalDisconnect = false;
      _isMqttConnected = false;
      return;
    }
    _isMqttConnected = false;
    _startReconnectTimer();
  }

  // ================================================================== //
  //  Publish
  // ================================================================== //

  void publishLocation(
      double lat, double lon, double accuracy, double speed) {
    final payload = {
      'device_id':    _deviceId,
      'company_code': _companyCode,
      'emp_name':     _empName,
      'dept_id':      _depId,
      'emp_image':    _empImage,
      'track_id':     DateTime.now().millisecondsSinceEpoch,
      'lat':          lat,
      'lon':          lon,
      'accuracy':     accuracy,
      'speed':        speed,
      'timestamp':    DateTime.now().toIso8601String(),
      'source':       'flutter_foreground',
    };
    debugPrint('📦 [Publish] dept_id=$_depId | emp_image=$_empImage | topic=$_mqttTopic');

    if (!_isMqttConnected || _mqttClient == null) {
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
    } catch (e) {
      debugPrint('❌ [Publish] error: $e — routing to offline queue');
      _enqueueOffline(payload);
      _isMqttConnected = false;
    }
  }

  // ================================================================== //
  //  Location Updates
  // ================================================================== //

  void startLocationPublishing() {
    _locationTimer?.cancel();
    _locationTimer =
        Timer.periodic(const Duration(seconds: 5), (_) async {
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

            publishLocation(
                pos.latitude, pos.longitude, pos.accuracy, pos.speed);
          } catch (e) {
            debugPrint('❌ [Location] GPS error: $e');
          }
        });
  }

  void stopLocationPublishing() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  // ================================================================== //
  //  Reconnect Timer
  // ================================================================== //

  void _startReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer =
        Timer.periodic(const Duration(seconds: 10), (_) async {
          if (_isMqttConnected) {
            _reconnectTimer?.cancel();
            return;
          }
          final ok = await connectMqtt();
          if (ok) {
            _reconnectTimer?.cancel();
            await _flushOfflineQueue();
          }
        });
  }

  void _startQueueFlushTimer() {
    _queueFlushTimer?.cancel();
    _queueFlushTimer =
        Timer.periodic(const Duration(seconds: 30), (_) {
          if (_isMqttConnected) _flushOfflineQueue();
        });
  }

  // ================================================================== //
  //  Clock In
  // ================================================================== //

  Future<bool> clockInMqtt({
    required String deviceId,
    required String companyCode,
    required String empName,
    required String empImage,
    required String depId,
  }) async {
    debugPrint(
        '🟢 [ClockIn] clockInMqtt() — deviceId=$deviceId | company=$companyCode | emp=$empName');

    _deviceId    = deviceId;
    _companyCode = companyCode;
    _empName     = empName;
    _empImage    = empImage;
    _depId       = depId;
    debugPrint('🧩 [ClockIn] depId=$_depId | empImage=$_empImage');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', deviceId);
    await prefs.setString('company_code', companyCode);
    await prefs.setString('emp_name', empName);
    await prefs.setBool('flutter.isClockedIn', true);
    await prefs.setInt(
        'flutter.clockInTimeMs', DateTime.now().millisecondsSinceEpoch);

    // ── FIX: Request battery optimization exemption ──────────────────
    // This is CRITICAL for background survival on Chinese OEM phones
    // (Xiaomi, Huawei, Oppo, Vivo, Realme, Samsung, OnePlus).
    // Without this, the OS kills the foreground service within minutes.
    try {
      await _serviceChannel.invokeMethod('requestBatteryOptimization');
      debugPrint('🟢 [ClockIn] ✅ Battery optimization exemption requested');
    } catch (e) {
      debugPrint('⚠️ [ClockIn] Battery optimization request failed: $e');
    }

    // ── FIX: Start Kotlin foreground service WITH identity ───────────
    // Previously startService was called without arguments, so the Kotlin
    // service had empty deviceId/companyCode/empName and published to
    // MQTT topic "gps//" instead of "gps/{company}/{user}".
    try {
      await _serviceChannel.invokeMethod('startService', {
        'deviceId':    deviceId,
        'companyCode': companyCode,
        'empName':     empName,
      });
      debugPrint('🟢 [ClockIn] ✅ Kotlin background service started with identity');
    } catch (e) {
      debugPrint('⚠️ [ClockIn] Could not start background service: $e');
    }

    final ok = await connectMqtt();
    if (ok) {
      startLocationPublishing();
      _startQueueFlushTimer();
      return true;
    } else {
      startLocationPublishing();
      _startReconnectTimer();
      _startQueueFlushTimer();
      return false;
    }
  }

  // ================================================================== //
  //  Clock Out
  // ================================================================== //

  Future<void> clockOutMqtt() async {
    debugPrint('🔴 [ClockOut] clockOutMqtt()');
    stopLocationPublishing();
    stopNetworkMonitoring();
    _reconnectTimer?.cancel();
    _queueFlushTimer?.cancel();

    if (_isMqttConnected) {
      await _flushOfflineQueue();
    }

    _intentionalDisconnect = true;
    try { _mqttClient?.disconnect(); } catch (e) {
      debugPrint('⚠️ [ClockOut] disconnect error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('flutter.isClockedIn', false);
    await prefs.remove('flutter.clockInTimeMs');

    try {
      await _serviceChannel.invokeMethod('stopService');
      debugPrint('🔴 [ClockOut] background service stopped');
    } catch (e) {
      debugPrint('⚠️ [ClockOut] stopService error: $e');
    }

    debugPrint('✅ [ClockOut] complete');
  }

  // ================================================================== //
  //  Cleanup
  // ================================================================== //

  Future<void> dispose() async {
    stopLocationPublishing();
    stopNetworkMonitoring();
    _reconnectTimer?.cancel();
    _queueFlushTimer?.cancel();
    _intentionalDisconnect = true;
    try { _mqttClient?.disconnect(); } catch (_) {}
    await _db?.close();
  }
}