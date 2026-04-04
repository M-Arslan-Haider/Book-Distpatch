// ============================================================
//  mqtt_work.dart — GPS MQTT Tracker (INTEGRATED INTO TIMER_CARD)
//  ✅ Clock In/Out linking via TimerCard._handleClockIn/Out
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

const String _mqttHost  = '103.149.33.102';
const int    _mqttPort  = 1883;
const String _mqttTopic = 'gps/location';

// MethodChannel to control Kotlin background service
const _serviceChannel = MethodChannel('com.example.untitled2/mqtt_service');

class MqttTracker {
  static final MqttTracker _instance = MqttTracker._internal();

  factory MqttTracker() => _instance;
  MqttTracker._internal();

  // ================================================================== //
  //  State
  // ================================================================== //
  bool _isMqttConnected      = false;
  bool _isConnecting         = false;
  bool _intentionalDisconnect = false;

  double? _lat, _lon, _accuracy, _speed;
  int _publishCount   = 0;
  int _queuedCount    = 0;

  Timer? _locationTimer, _reconnectTimer, _queueFlushTimer;
  MqttServerClient? _mqttClient;

  String _deviceId = 'DEVICE_000';
  Database? _db;

  // ================================================================== //
  //  Getters
  // ================================================================== //
  bool get isMqttConnected => _isMqttConnected;
  bool get isConnecting => _isConnecting;
  int get queuedCount => _queuedCount;
  int get publishCount => _publishCount;

  // ================================================================== //
  //  Initialization
  // ================================================================== //

  Future<void> initialize() async {
    await _initDb();
    await _initializeDeviceId();
    await _refreshQueueCount();
  }

  // ================================================================== //
  //  SQLite — Unlimited Offline Queue
  // ================================================================== //

  Future<void> _initDb() async {
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
      debugPrint('❌ SQLite init error: $e');
    }
  }

  Future<void> _enqueueOffline(Map<String, dynamic> payload) async {
    try {
      if (_db == null) await _initDb();
      await _db!.insert('offline_queue', {
        'payload': jsonEncode(payload),
        'created': DateTime.now().millisecondsSinceEpoch,
      });
      await _refreshQueueCount();
      debugPrint('💾 Offline queued (total: $_queuedCount)');
    } catch (e) {
      debugPrint('❌ Queue error: $e');
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
              _mqttTopic, MqttQos.atLeastOnce, builder.payload!, retain: false);

          await _db!.delete('offline_queue',
              where: 'id = ?', whereArgs: [row['id']]);
          _publishCount++;
          sent++;
        } catch (_) {}
      }

      await _refreshQueueCount();
      debugPrint('✅ Flushed: $sent sent, $_queuedCount remaining');
    } catch (e) {
      debugPrint('❌ Flush error: $e');
    }
  }

  Future<void> _refreshQueueCount() async {
    try {
      if (_db == null) return;
      final result = await _db!.rawQuery('SELECT COUNT(*) as cnt FROM offline_queue');
      final count  = (result.first['cnt'] as int?) ?? 0;
      _queuedCount = count;
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
        debugPrint('👤 User: $_deviceId');
      } else {
        _deviceId = 'USER_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      debugPrint('⚠️ Device ID error: $e');
    }
  }

  // ================================================================== //
  //  MQTT Connect
  // ================================================================== //

  Future<bool> connectMqtt() async {
    if (_isMqttConnected || _isConnecting) return _isMqttConnected;

    _isConnecting = true;
    debugPrint('📡 Connecting to MQTT broker...');

    for (final cfg in [
      {'protocol': 'v311', 'name': 'MQTT 3.1.1'},
      {'protocol': 'v31',  'name': 'MQTT 3.1'},
    ]) {
      if (await _tryConnect(cfg['protocol']!)) {
        debugPrint('✅ Connected (${cfg['name']})');
        _isConnecting = false;
        return true;
      }
    }

    _isConnecting = false;
    debugPrint('❌ All protocols failed');
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

      if (protocol == 'v31') _mqttClient!.setProtocolV31();
      else _mqttClient!.setProtocolV311();

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
      debugPrint('❌ $protocol failed: $e');
      try { _mqttClient?.disconnect(); } catch (_) {}
      return false;
    }
  }

  void _onMqttConnected() {
    _isMqttConnected = true;
    debugPrint('✅ MQTT Connected');
    _flushOfflineQueue();
  }

  void _onMqttDisconnected() {
    if (_intentionalDisconnect) {
      _intentionalDisconnect = false;
      debugPrint('📱 MQTT handed off to background service');
      _isMqttConnected = false;
      return;
    }
    _isMqttConnected = false;
    debugPrint('⚠️ MQTT Disconnected — data queued locally');
    _startReconnectTimer();
  }

  // ================================================================== //
  //  Publish — saves to SQLite queue if not connected
  // ================================================================== //

  void publishLocation(double lat, double lon, double accuracy, double speed) {
    final payload = {
      'device_id': _deviceId,
      'track_id':  DateTime.now().millisecondsSinceEpoch,
      'lat':       lat,
      'lon':       lon,
      'accuracy':  accuracy,
      'speed':     speed,
      'timestamp': DateTime.now().toIso8601String(),
      'source':    'flutter_foreground',
    };

    if (!_isMqttConnected || _mqttClient == null) {
      _enqueueOffline(payload);
      return;
    }

    try {
      final builder = MqttClientPayloadBuilder()..addString(jsonEncode(payload));
      _mqttClient!.publishMessage(_mqttTopic, MqttQos.atLeastOnce, builder.payload!, retain: false);
      _publishCount++;
      debugPrint('📤 Published #$_publishCount | $lat, $lon');
    } catch (e) {
      debugPrint('❌ Publish error — queuing: $e');
      _enqueueOffline(payload);
      _isMqttConnected = false;
    }
  }

  // ================================================================== //
  //  Location Updates (called during Clock In)
  // ================================================================== //

  void startLocationPublishing() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
        );
        _lat = pos.latitude;
        _lon = pos.longitude;
        _accuracy = pos.accuracy;
        _speed = pos.speed;

        publishLocation(pos.latitude, pos.longitude, pos.accuracy, pos.speed);
      } catch (e) {
        debugPrint('❌ Location error: $e');
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
    _reconnectTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_isMqttConnected) {
        _reconnectTimer?.cancel();
        return;
      }
      debugPrint('🔄 Retry MQTT connect...');
      final ok = await connectMqtt();
      if (ok) {
        _reconnectTimer?.cancel();
        debugPrint('✅ Reconnected');
        await _flushOfflineQueue();
      }
    });
  }

  void _startQueueFlushTimer() {
    _queueFlushTimer?.cancel();
    _queueFlushTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isMqttConnected) _flushOfflineQueue();
    });
  }

  // ================================================================== //
  //  Clock In (called from timer_card.dart)
  // ================================================================== //

  Future<bool> clockInMqtt({required String deviceId}) async {
    _deviceId = deviceId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', deviceId);
    await prefs.setBool('flutter.isClockedIn', true);
    await prefs.setInt('flutter.clockInTimeMs', DateTime.now().millisecondsSinceEpoch);

    final ok = await connectMqtt();
    if (ok) {
      startLocationPublishing();
      _startQueueFlushTimer();
      debugPrint('✅ MQTT Clock In complete');
      return true;
    } else {
      debugPrint('⚠️ MQTT unavailable — will queue locations offline');
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
    stopLocationPublishing();
    _reconnectTimer?.cancel();
    _queueFlushTimer?.cancel();

    if (_isMqttConnected) {
      await _flushOfflineQueue();
    }

    _intentionalDisconnect = true;
    try { _mqttClient?.disconnect(); } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('flutter.isClockedIn', false);
    await prefs.remove('flutter.clockInTimeMs');

    try {
      await _serviceChannel.invokeMethod('stopService');
    } catch (_) {}

    debugPrint('✅ MQTT Clock Out complete');
  }

  // ================================================================== //
  //  Cleanup
  // ================================================================== //

  Future<void> dispose() async {
    stopLocationPublishing();
    _reconnectTimer?.cancel();
    _queueFlushTimer?.cancel();
    _intentionalDisconnect = true;
    try { _mqttClient?.disconnect(); } catch (_) {}
    await _db?.close();
  }
}