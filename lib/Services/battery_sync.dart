// ═══════════════════════════════════════════════════════════════════════════
// battery_sync.dart
// Complete battery mode tracking: detect → save locally → sync in background
// Works offline or online. Add this ONE file to your project.
//
// ⚠️ IMPORTANT: is file mein sirf watcher/service DEFINE hote hain.
// Inhein kaam karne ke liye kisi ek jagah (jaise Clock-In hone par)
// BatteryLifecycleWatcher(...).start() explicitly CALL karna zaroori hai —
// warna _checkAndReport() kabhi chalega hi nahi aur na local insert hoga
// na hi Oracle par POST jayega. Neeche debug prints add kiye hain taake
// exactly pata chale flow kahan atak raha hai.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../Database/db_helper.dart';

// ─────────────────────────────────────────────────────────────────────────
// 1) NATIVE BRIDGE — MainActivity.kt ke "getBatteryMode" method ko call karta hai
// ─────────────────────────────────────────────────────────────────────────
class BatteryService {
  // ✅ FIXED: Match MainActivity.kt ka MQTT_CHANNEL
  static const MethodChannel _channel =
  MethodChannel('com.example.untitled2/mqtt_service');

  /// Returns "UNRESTRICTED" / "RESTRICTED" / "OPTIMIZED" / "UNKNOWN"
  static Future<String> getBatteryMode() async {
    debugPrint('🔍 [BatteryService] getBatteryMode() CALLED — invoking native channel...');
    try {
      final String mode = await _channel.invokeMethod('getBatteryMode');
      debugPrint('🔋 [BatteryService] ✅ Native returned mode=$mode');
      return mode;
    } on MissingPluginException catch (e) {
      debugPrint('🚨 [BatteryService] MissingPluginException — channel name mismatch '
          'ya MainActivity mein handler register nahi. Detail: $e');
      return 'UNKNOWN';
    } on PlatformException catch (e) {
      debugPrint('🚨 [BatteryService] PlatformException from native side: '
          'code=${e.code} message=${e.message} details=${e.details}');
      return 'UNKNOWN';
    } catch (e, st) {
      debugPrint('❌ [BatteryService] Unexpected error: $e');
      debugPrint('❌ [BatteryService] StackTrace: $st');
      return 'UNKNOWN';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 2) TABLE DEFINITION — db_helper.dart mein already add ki gayi
//    batteryEventsTable / insertBatteryEvent / getPendingBatteryEvents /
//    markBatteryEventSynced methods ko yahan se use kiya ja raha hai.
// ─────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────
// 3) API SERVICE — Oracle ORDS endpoint par POST
// ─────────────────────────────────────────────────────────────────────────
class BatteryEventsApiService {
  static const String _endpoint =
      'http://oracle.metaxperts.net/ords/gps_workforce/battery_events/post';

  static Future<bool> postBatteryEvent({
    required String empId,
    required String empName,
    required String companyCode,
    required String batteryMode,
    required String eventTime,
  }) async {
    debugPrint(
        '📡 [BatteryApi] POST → url=$_endpoint empId=$empId mode=$batteryMode time=$eventTime');
    try {
      final response = await http
          .post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'emp_id': empId,
          'emp_name': empName,
          'company_code': companyCode,
          'battery_mode': batteryMode,
          'event_time': eventTime,
          'synced': 1,
        }),
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('📡 [BatteryApi] Response status=${response.statusCode}');
      debugPrint('📡 [BatteryApi] Response body=${response.body}');

      final ok = response.statusCode == 200 || response.statusCode == 201;
      if (ok) {
        debugPrint('✅ [BatteryApi] POST accepted by server');
      } else {
        debugPrint('❌ [BatteryApi] Server rejected — status=${response.statusCode} body=${response.body}');
      }
      return ok;
    } catch (e, st) {
      debugPrint('❌ [BatteryApi] Exception (offline / URL / SSL?): $e');
      debugPrint('❌ [BatteryApi] StackTrace: $st');
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 4) BACKGROUND SYNC — pending records ko retry karta hai
// ─────────────────────────────────────────────────────────────────────────
class BatterySyncService {
  static Future<void> syncPendingBatteryEvents() async {
    debugPrint('🔁 [BatterySync] syncPendingBatteryEvents() CALLED');
    final dbHelper = DBHelper();
    final pending = await dbHelper.getPendingBatteryEvents();

    debugPrint('🔁 [BatterySync] Pending rows fetched from SQLite: ${pending.length}');

    if (pending.isEmpty) {
      debugPrint('ℹ️ [BatterySync] Koi pending record nahi — agar ye hamesha 0 dikhe '
          'to iska matlab insertBatteryEvent() kabhi call hi nahi ho raha '
          '(watcher start nahi hua, ya mode hamesha UNKNOWN/same aa raha hai).');
      return;
    }

    debugPrint('🔁 [BatterySync] ${pending.length} pending record(s) — sync shuru');

    for (final row in pending) {
      debugPrint('🔁 [BatterySync] Syncing row id=${row['id']} → $row');
      final success = await BatteryEventsApiService.postBatteryEvent(
        empId: row['emp_id'] ?? '',
        empName: row['emp_name'] ?? '',
        companyCode: row['company_code'] ?? '',
        batteryMode: row['battery_mode'] ?? '',
        eventTime: row['event_time'] ?? '',
      );

      if (success) {
        await dbHelper.markBatteryEventSynced(row['id'] as int);
        debugPrint('✅ [BatterySync] id=${row['id']} synced + marked in SQLite');
      } else {
        debugPrint('❌ [BatterySync] id=${row['id']} fail — agli baar retry');
      }
    }

    debugPrint('🔁 [BatterySync] syncPendingBatteryEvents() DONE');
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 5) WATCHER — mode-change detect karta hai + local save + turant sync try
// ─────────────────────────────────────────────────────────────────────────
class BatteryLifecycleWatcher with WidgetsBindingObserver {
  final String empId;
  final String empName;
  final String companyCode;

  String? _lastKnownMode;
  Timer? _periodicTimer;
  StreamSubscription? _connectivitySub;

  BatteryLifecycleWatcher({
    required this.empId,
    required this.empName,
    required this.companyCode,
  });

  void start() {
    debugPrint('🟢 [BatteryWatcher] start() empId=$empId empName=$empName companyCode=$companyCode');
    WidgetsBinding.instance.addObserver(this);

    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      debugPrint('🌐 [BatteryWatcher] Connectivity changed → $result');
      if (result != ConnectivityResult.none) {
        debugPrint('🌐 [BatteryWatcher] Internet wapas aaya — sync trigger');
        BatterySyncService.syncPendingBatteryEvents();
      }
    });

    _periodicTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      debugPrint('⏰ [BatteryWatcher] Periodic 60s tick');
      _checkAndReport();
    });

    _checkAndReport();
  }

  void stop() {
    debugPrint('🔴 [BatteryWatcher] stop()');
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    _connectivitySub?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('🔄 [BatteryWatcher] Lifecycle: $state');
    if (state == AppLifecycleState.resumed) {
      _checkAndReport();
      BatterySyncService.syncPendingBatteryEvents();
    }
  }

  Future<void> _checkAndReport() async {
    debugPrint('🔍 [BatteryWatcher] _checkAndReport() CALLED | empId="$empId"');

    if (empId.isEmpty) {
      debugPrint('⚠️ [BatteryWatcher] empId khali hai — skip.');
      return;
    }

    final mode = await BatteryService.getBatteryMode();
    debugPrint('🔋 [BatteryWatcher] mode=$mode | lastKnownMode=$_lastKnownMode');

    if (mode == 'UNKNOWN') {
      debugPrint('🚨 [BatteryWatcher] mode=UNKNOWN — native channel se response nahi mila.');
      return;
    }

    if (mode != _lastKnownMode) {
      debugPrint('🔁 [BatteryWatcher] Mode CHANGED ($_lastKnownMode → $mode)');

      final dbHelper = DBHelper();
      await dbHelper.insertBatteryEvent(
        empId: empId,
        empName: empName,
        companyCode: companyCode,
        batteryMode: mode,
      );
      debugPrint('💾 [BatteryWatcher] insertBatteryEvent() DONE for mode=$mode');

      _lastKnownMode = mode;

      await BatterySyncService.syncPendingBatteryEvents();
    } else {
      debugPrint('ℹ️ [BatteryWatcher] Mode same hai ($mode) — skip');
    }
  }
}