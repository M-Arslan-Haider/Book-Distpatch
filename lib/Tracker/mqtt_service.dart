// lib/Services/mqtt_service.dart
//
// EMQX Broker : 103.149.33.102:1883
// Topic       : gps/<emp_id>
// Auth        : none

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  // ── ⚙️  SERVER SETTINGS ───────────────────────────────────────────────────
  static const String _broker   = '103.149.33.102';
  static const int    _port     = 1883;
  static const String _username = ''; // no auth
  static const String _password = ''; // no auth
  // ─────────────────────────────────────────────────────────────────────────

  MqttServerClient? _client;
  bool   _connected      = false;
  String _empId          = '';
  int    _publishCount   = 0;       // total messages sent this session
  int    _failCount      = 0;       // total failed publishes
  DateTime? _connectedAt;           // when connection was established

  // ── Connect ───────────────────────────────────────────────────────────────

  Future<void> connect(String empId) async {
    _empId = empId;
    final clientId =
        'flutter_gps_${empId}_${DateTime.now().millisecondsSinceEpoch}';

    print('╔══════════════════════════════════════════════');
    print('║  [MQTT] Connecting...');
    print('║  Broker   : $_broker');
    print('║  Port     : $_port');
    print('║  ClientId : $clientId');
    print('║  EmpId    : $empId');
    print('║  Auth     : ${_username.isEmpty ? "none" : _username}');
    print('╚══════════════════════════════════════════════');

    _client = MqttServerClient.withPort(_broker, clientId, _port);
    _client!.keepAlivePeriod              = 60;
    _client!.autoReconnect                = true;
    _client!.resubscribeOnAutoReconnect   = false;
    _client!.logging(on: true); // ← enables raw MQTT packet logs in console

    _client!.onConnected      = _onConnected;
    _client!.onDisconnected   = _onDisconnected;
    _client!.onAutoReconnect  = _onAutoReconnect;
    _client!.onSubscribed     = _onSubscribed;
    _client!.onUnsubscribed   = _onUnsubscribed;
    _client!.pongCallback     = _onPong;

    final connMsg = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    if (_username.isNotEmpty) {
      connMsg.authenticateAs(_username, _password);
      print('[MQTT] 🔐 Using credentials: $_username');
    }

    _client!.connectionMessage = connMsg;

    try {
      print('[MQTT] ⏳ Attempting TCP connection to $_broker:$_port ...');
      final status = await _client!.connect();

      print('[MQTT] 📶 Connection status returned: ${status?.state}');
      print('[MQTT] 📶 Return code: ${status?.returnCode}');

      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        _connected   = true;
        _connectedAt = DateTime.now();
        _publishCount = 0;
        _failCount    = 0;
        print('╔══════════════════════════════════════════════');
        print('║  [MQTT] ✅ CONNECTED SUCCESSFULLY');
        print('║  Broker : $_broker:$_port');
        print('║  Time   : $_connectedAt');
        print('╚══════════════════════════════════════════════');
      } else {
        print('╔══════════════════════════════════════════════');
        print('║  [MQTT] ❌ CONNECTION FAILED');
        print('║  State  : ${_client!.connectionStatus?.state}');
        print('║  Code   : ${_client!.connectionStatus?.returnCode}');
        print('╚══════════════════════════════════════════════');
        _client!.disconnect();
      }
    } on NoConnectionException catch (e) {
      print('[MQTT] ❌ NoConnectionException: $e');
      print('[MQTT] 👉 Check broker IP and port are correct');
      _client?.disconnect();
    } on Exception catch (e) {
      print('[MQTT] ❌ Exception during connect: $e');
      _client?.disconnect();
    }
  }

  // ── Publish lat/lng ───────────────────────────────────────────────────────
  //
  // Topic:   gps/<emp_id>
  // Payload: { "emp_id":"EMP001","lat":31.5204,"lon":74.3587,"timestamp":"..." }

  void publishLocation(double lat, double lon, String empId) {
    final id = empId.isEmpty ? _empId : empId;

    // ── Pre-flight checks ──────────────────────────────────────────────────
    if (_client == null) {
      print('[MQTT] ❌ PUBLISH FAILED — client is null (never connected)');
      _failCount++;
      return;
    }

    if (!_connected) {
      print('[MQTT] ❌ PUBLISH FAILED — not connected to broker');
      print('[MQTT]    State: ${_client!.connectionStatus?.state}');
      _failCount++;
      return;
    }

    if (_client!.connectionStatus?.state != MqttConnectionState.connected) {
      print('[MQTT] ❌ PUBLISH FAILED — unexpected state: '
          '${_client!.connectionStatus?.state}');
      _failCount++;
      return;
    }

    // ── Build message ──────────────────────────────────────────────────────
    final topic     = 'gps/$id';
    final timestamp = DateTime.now().toIso8601String();
    final payload   = '{'
        '"emp_id":"$id",'
        '"lat":$lat,'
        '"lon":$lon,'
        '"timestamp":"$timestamp"'
        '}';

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      final msgId = _client!.publishMessage(
        topic,
        MqttQos.atLeastOnce,
        builder.payload!,
        retain: false,
      );

      _publishCount++;

      print('┌─────────────────────────────────────────────');
      print('│ [MQTT] 📡 PUBLISHED #$_publishCount');
      print('│ Topic   : $topic');
      print('│ MsgId   : $msgId');
      print('│ Lat     : $lat');
      print('│ Lon     : $lon');
      print('│ Time    : $timestamp');
      print('│ Payload : $payload');
      print('│ Session : ${_sessionDuration()}');
      print('│ Failed  : $_failCount');
      print('└─────────────────────────────────────────────');
    } catch (e) {
      _failCount++;
      print('┌─────────────────────────────────────────────');
      print('│ [MQTT] ❌ PUBLISH ERROR #$_failCount');
      print('│ Topic : $topic');
      print('│ Error : $e');
      print('└─────────────────────────────────────────────');
    }
  }

  // ── Disconnect ────────────────────────────────────────────────────────────

  void disconnect() {
    print('╔══════════════════════════════════════════════');
    print('║  [MQTT] Disconnecting...');
    print('║  Total Published : $_publishCount messages');
    print('║  Total Failed    : $_failCount messages');
    print('║  Session Duration: ${_sessionDuration()}');
    print('╚══════════════════════════════════════════════');
    try {
      _client?.disconnect();
    } catch (_) {}
    _connected = false;
  }

  // ── Callbacks ─────────────────────────────────────────────────────────────

  void _onConnected() {
    _connected   = true;
    _connectedAt = DateTime.now();
    print('[MQTT] 🟢 onConnected callback fired — broker accepted connection');
  }

  void _onDisconnected() {
    _connected = false;
    print('[MQTT] 🔴 onDisconnected callback fired');
    print('[MQTT]    Published this session : $_publishCount');
    print('[MQTT]    Failed this session    : $_failCount');
    print('[MQTT]    Last state: ${_client?.connectionStatus?.state}');
  }

  void _onAutoReconnect() {
    print('[MQTT] 🔄 Auto-reconnect triggered — broker unreachable, retrying...');
  }

  void _onSubscribed(String topic) {
    print('[MQTT] ✅ Subscribed to topic: $topic');
  }

  void _onUnsubscribed(String? topic) {
    print('[MQTT] ⚠️ Unsubscribed from topic: $topic');
  }

  void _onPong() {
    print('[MQTT] 🏓 Pong received — broker is alive');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _sessionDuration() {
    if (_connectedAt == null) return 'not connected';
    final diff = DateTime.now().difference(_connectedAt!);
    final h    = diff.inHours.toString().padLeft(2, '0');
    final m    = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s    = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── Status (call anytime to print current state) ──────────────────────────

  void printStatus() {
    print('╔══════════════════════════════════════════════');
    print('║  [MQTT] STATUS');
    print('║  Connected       : $_connected');
    print('║  Broker          : $_broker:$_port');
    print('║  EmpId           : $_empId');
    print('║  Published       : $_publishCount messages');
    print('║  Failed          : $_failCount messages');
    print('║  Session Duration: ${_sessionDuration()}');
    print('║  Client State    : ${_client?.connectionStatus?.state}');
    print('╚══════════════════════════════════════════════');
  }

  bool get isConnected => _connected;
}